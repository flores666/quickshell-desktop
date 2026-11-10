#include "ElasticState.hpp"

#include <hyprland/src/animation/WorkspaceAnimationController.hpp>
#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/desktop/view/window/WindowPresentation.hpp>
#include <hyprland/src/desktop/state/GlobalWindowController.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/managers/eventLoop/EventLoopManager.hpp>
#include <hyprland/src/state/MonitorState.hpp>
#include <hyprland/src/state/WorkspaceState.hpp>
#include <hyprland/src/config/shared/workspace/WorkspaceRuleManager.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/ipc/s2/S2.hpp>

namespace {
    SP<CEventLoopTimer> dwell;
    int direction = 0;
    PHLMONITORREF edgeMonitor;
    PHLWORKSPACEREF sliding;
    struct Slide {
        PHLWORKSPACEREF workspace;
        SP<::Style::Config> previous, config;
    };
    std::vector<Slide> slides;

    void finished(PHLWORKSPACE workspace) {
        for (auto it = slides.begin(); it != slides.end(); ++it)
            if (it->workspace.lock() == workspace) {
                workspace->m_renderOffset->setConfig(it->previous);
                slides.erase(it);
                break;
            }
        if (sliding.lock() == workspace) {
            sliding.reset();
            ElasticDrag::edgeMotion();
        }
    }

    int atEdge() {
        const auto S = ElasticDrag::session;
        const auto M = S ? S->monitor.lock() : nullptr;
        if (!S || !M || !S->held || S->external || !M->m_activeWorkspace || M->m_activeSpecialWorkspace) return 0;
        const auto P = S->cursor - M->m_position;
        const double EDGE = ElasticDrag::Style::value("edge");
        const int DIR = P.x <= EDGE ? -1 : P.x >= M->m_size.x - EDGE ? 1 : 0;
        if (!DIR || P.y < 0 || P.y >= M->m_size.y) return 0;
        // A physical neighbouring monitor takes precedence over workspace edges.
        const auto NEIGHBOUR = State::monitorState()->query().vec(M->m_position + Vector2D{DIR < 0 ? -1.0 : M->m_size.x + 1, P.y}).run();
        if (NEIGHBOUR && NEIGHBOUR != M) return 0;
        const auto ID = M->m_activeWorkspace->numberedID();
        return ID && (*ID > 1 || DIR > 0) ? DIR : 0;
    }

    void transfer() {
        const auto S = ElasticDrag::session;
        const auto M = edgeMonitor.lock();
        const auto W = S ? S->window.lock() : nullptr;
        if (!S || !M || !W || direction == 0 || atEdge() != direction || S->monitor.lock() != M) return;
        const auto FROM = M->m_activeWorkspace;
        auto id = sc<int64_t>(*FROM->numberedID()) + direction;
        PHLWORKSPACE to;
        // Numbered workspaces bound to another monitor are never stolen.
        for (; id > 0 && id <= UINT32_MAX; id += direction) {
            const auto BOUND = Config::workspaceRuleMgr()->getBoundMonitorForWS(std::to_string(id));
            to = State::workspaceState()->query().numbered(::Workspace::SWorkspaceNumberedID{sc<uint32_t>(id)}).run();
            if ((!BOUND || BOUND == M) && (!to || to->m_monitor.lock() == M)) break;
        }
        if (id <= 0 || id > UINT32_MAX) return;
        if (!to) to = State::workspaceState()->createNumbered(::Workspace::SWorkspaceNumberedID{sc<uint32_t>(id)}, M);
        if (!to) return;
        const CBox BOX{W->position(Desktop::View::IGeometric::GEOMETRIC_CURRENT), W->size(Desktop::View::IGeometric::GEOMETRIC_CURRENT)};
        // The internal workspace switch preserves the real held button and
        // device grab. The public switch intentionally releases all buttons.
        Desktop::globalWindowController()->moveWindowToWorkspace(W, to);
        M->changeWorkspace(to, true, true, true);
        W->layoutTarget()->setPositionGlobal(BOX);
        W->layoutTarget()->warpPositionSize();
        W->presentation().alpha(Desktop::View::WINDOW_ALPHA_MOVE_TO_WORKSPACE)->setValueAndWarp(1.F);
        W->presentation().alpha(Desktop::View::WINDOW_ALPHA_MOVE_FROM_WORKSPACE)->setValueAndWarp(1.F);
        W->presentation().resetMonitorMovedFrom();
        Desktop::focusState()->rawWindowFocus(W, Desktop::FOCUS_REASON_DESKTOP_STATE_CHANGE);
        g_layoutManager->recalculateMonitor(M, Layout::CLayoutManager::RECALCULATE_MONITOR_REASON_WORKSPACE_CHANGE);
        Animation::Workspace::startAnimation(FROM, Animation::Workspace::ANIMATION_TYPE_OUT, direction > 0, false, "slide");
        Animation::Workspace::startAnimation(to, Animation::Workspace::ANIMATION_TYPE_IN, direction > 0, false, "slide");
        const auto CONFIG = ElasticDrag::Style::workspaceConfig();
        sliding = to;
        for (const auto& ws : {FROM, to}) {
            slides.push_back({ws, ws->m_renderOffset->getConfig().lock(), CONFIG});
            ws->m_renderOffset->setConfig(CONFIG);
            ws->m_renderOffset->setCallbackOnEnd([weak = PHLWORKSPACEREF{ws}](auto) {
                if (const auto workspace = weak.lock()) finished(workspace);
            });
        }
        to->ready();
        IPC::Socket2::sock()->postEvent({"workspace", to->addressableName()});
        Event::bus()->m_events.workspace.active.emit(to);
        direction = 0;
        ElasticDrag::damage();
    }
}

void ElasticDrag::edgeInit() {
    dwell = makeShared<CEventLoopTimer>(std::nullopt, [](SP<CEventLoopTimer>, void*) { transfer(); }, nullptr);
    g_pEventLoopManager->addTimer(dwell);
}

void ElasticDrag::edgeClear() {
    if (dwell) dwell->updateTimeout(std::nullopt);
    direction = 0;
    edgeMonitor.reset();
}

void ElasticDrag::edgeExit() {
    edgeClear();
    for (const auto& slide : slides)
        if (const auto W = slide.workspace.lock()) {
            W->m_renderOffset->setCallbackOnEnd({});
            W->m_renderOffset->setConfig(slide.previous);
        }
    slides.clear();
    sliding.reset();
    if (dwell) g_pEventLoopManager->removeTimer(dwell);
    dwell.reset();
}

void ElasticDrag::edgeMotion() {
    if (!dwell) return;
    const int DIR = atEdge();
    if (!DIR) { edgeClear(); return; }
    if (const auto W = sliding.lock(); W && W->m_renderOffset->isBeingAnimated()) return;
    if (direction == DIR && edgeMonitor == session->monitor) return;
    direction = DIR;
    edgeMonitor = session->monitor;
    dwell->updateTimeout(std::chrono::milliseconds(sc<int>(Style::value("edge_dwell"))));
    damage();
}

void ElasticDrag::edgePaint(Render::CRenderContext& ctx, PHLMONITOR monitor) {
    if (!direction || edgeMonitor.lock() != monitor) return;
    const double W = Style::value("indicator_width"), H = Style::value("indicator_height");
    CRectPassElement::SRectData data;
    data.box = CBox{direction < 0 ? W : monitor->m_size.x - 2 * W, (monitor->m_size.y - H) / 2, W, H}.scale(monitor->m_scale);
    data.color = Style::indicator();
    data.round = W * monitor->m_scale / 2;
    Render::IHyprRenderer::addPassElement(ctx, makeUnique<CRectPassElement>(data));
}
