#include "ElasticState.hpp"
#include "WindowMotion.hpp"
#include "TitleBar.hpp"

#include <hyprland/src/animation/AnimationManager.hpp>
#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/desktop/view/window/WindowEffectsController.hpp>
#include <hyprland/src/desktop/view/window/WindowPresentation.hpp>
#include <hyprland/src/desktop/rule/windowRule/WindowRuleApplicator.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/render/transformer/TransformerList.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/output/Monitor.hpp>
#include <hyprland/src/plugins/HookSystem.hpp>
#include <hyprland/src/managers/SessionLockManager.hpp>
#include <linux/input-event-codes.h>
#include <iostream>

SP<ElasticDrag::Session> ElasticDrag::session;

namespace {
    HANDLE handle;
    CFunctionHook* beginHook = nullptr;
    std::vector<CHyprSignalListener> listeners;
    SP<Event::CEventBus::CCustomEvent> bridge;
    unsigned captureDepth = 0;
    PHLWINDOWREF pendingWindow;
    CBox pendingBox;
    using Begin = void (*)(void*, SP<Layout::ITarget>, eMouseBindMode, std::optional<Layout::eRectCorner>, bool);

    bool usable(PHLWINDOW w) {
        return !g_pSessionLockManager->isSessionLocked() && validMapped(w) && !w->isHidden() && w->m_workspace && w->m_monitor &&
            w->size(Desktop::View::IGeometric::GEOMETRIC_CURRENT).x > 0 && w->size(Desktop::View::IGeometric::GEOMETRIC_CURRENT).y > 0 && !w->m_ruleApplicator->noAnim().valueOrDefault();
    }

    void start(PHLWINDOW w, const CBox& box, bool external) {
        if (!usable(w) || !ElasticDrag::Style::enabled() || !g_pHyprRenderer->glBackend() || box.empty()) return;
        ElasticDrag::clear();
        WindowMotion::takeForDrag(w);
        auto state = makeShared<ElasticDrag::Session>();
        state->window = w;
        state->monitor = w->m_monitor;
        state->initial = state->displayed = box;
        state->external = external;
        state->cursor = state->lastCursor = g_pInputManager->getMouseCoordsInternal();
        state->grab = (state->cursor - box.pos()) / box.size();
        state->started = state->lastMotion = Time::steadyNow();
        ElasticDrag::session = state;
        ElasticDrag::attach(state);
        ElasticDrag::damage();
        Animation::mgr()->requestTick();
    }

    void nativeMotion() {
        const auto& DRAG = g_layoutManager->dragController();
        const auto TARGET = DRAG->target();
        if (!TARGET || DRAG->mode() != MBIND_MOVE || !DRAG->dragThresholdReached()) return;
        const auto W = TARGET->window();
        if (!usable(W)) return;
        if (!ElasticDrag::session || ElasticDrag::session->window.lock() != W || !ElasticDrag::session->held)
            start(W, pendingWindow.lock() == W ? pendingBox : CBox{W->position(Desktop::View::IGeometric::GEOMETRIC_CURRENT), W->size(Desktop::View::IGeometric::GEOMETRIC_CURRENT)}, false);
        pendingWindow.reset();
        const auto STATE = ElasticDrag::session;
        if (!STATE || STATE->external) return;
        ElasticDrag::damage();
        STATE->monitor = W->m_monitor;
        STATE->motion(g_pInputManager->getMouseCoordsInternal());
        // Native wobble and motion exposure must not compose a second spring.
        W->effects().resetWobble();
        W->effects().resetMotionBlur();
        ElasticDrag::edgeMotion();
        ElasticDrag::damage();
        Animation::mgr()->requestTick();
    }

    void begin(void* self, SP<Layout::ITarget> target, eMouseBindMode mode, std::optional<Layout::eRectCorner> edge, bool exclusive) {
        const auto W = target ? target->window() : nullptr;
        pendingWindow = mode == MBIND_MOVE && usable(W) ? W : nullptr;
        if (pendingWindow) pendingBox = {W->position(Desktop::View::IGeometric::GEOMETRIC_CURRENT), W->size(Desktop::View::IGeometric::GEOMETRIC_CURRENT)};
        if (const auto PRESS = Pointer::dragPress(W); PRESS && pendingWindow && !W->isFloating())
            pendingBox.translate(g_pInputManager->getMouseCoordsInternal() - *PRESS);
        ((Begin)beginHook->m_original)(self, target, mode, edge, exclusive);
        nativeMotion();
    }

    void ended() {
        pendingWindow.reset();
        const auto STATE = ElasticDrag::session;
        if (!STATE || !STATE->held || STATE->external) return;
        const auto W = STATE->window.lock();
        if (!usable(W)) { ElasticDrag::clear(); return; }
        const CBox TARGET{W->positionAnimation()->goal(), W->sizeAnimation()->goal()};
        ElasticDrag::release(TARGET);
        // The layout owns the drop (including tiling). Present its final box
        // through our landing instead of combining two geometry animations.
        W->finishAnimation();
    }

    void tick() {
        const auto STATE = ElasticDrag::session;
        if (!STATE) return;
        const auto W = STATE->window.lock();
        if (!usable(W) || !ElasticDrag::Style::enabled()) { ElasticDrag::clear(); return; }
        const auto NOW = Time::steadyNow();
        const auto age = [&](auto since) { return std::chrono::duration<double, std::milli>(NOW - since).count(); };
        ElasticDrag::damage();
        if (!STATE->held && age(STATE->dropped) >= ElasticDrag::Style::value("landing")) {
            ElasticDrag::clear();
            return;
        }
        if (!STATE->held || age(STATE->started) < ElasticDrag::Style::value("lift") || age(STATE->lastMotion) < ElasticDrag::Style::value("settle"))
            Animation::mgr()->requestTick();
    }

    void external(const std::vector<Event::CEventBus::CCustomEvent::ValidVariant>& args) {
        const int PHASE = std::get<int>(args[0]);
        if (PHASE == 5) { ++captureDepth; return; }
        if (PHASE == 6) { if (captureDepth) --captureDepth; return; }
        const auto W = std::get<PHLWINDOWREF>(args[1]).lock();
        const CBox BOX{std::get<double>(args[2]), std::get<double>(args[3]), std::get<double>(args[4]), std::get<double>(args[5])};
        if (PHASE == 0) start(W, BOX, true);
        else if (ElasticDrag::session && ElasticDrag::session->external && ElasticDrag::session->window.lock() == W) {
            if (PHASE == 1) {
                ElasticDrag::damage();
                ElasticDrag::session->motion(g_pInputManager->getMouseCoordsInternal());
                ElasticDrag::damage();
                Animation::mgr()->requestTick();
            } else if (PHASE == 2 || PHASE == 3) ElasticDrag::release(BOX.empty() ? ElasticDrag::session->initial : BOX);
        }
    }
}

void ElasticDrag::damage() {
    if (!session) return;
    if (const auto W = session->window.lock()) {
        const auto BOX = W->effects().transformBoxForDamage(W->getFullWindowBoundingBox());
        g_pHyprRenderer->damageBox(session->lastDamage);
        g_pHyprRenderer->damageBox(BOX);
        session->lastDamage = BOX;
    }
}

void ElasticDrag::clear() {
    edgeClear();
    if (!session) return;
    damage();
    const auto FINISHED = session;
    session->alive = false;
    if (const auto W = session->window.lock()) W->effects().transformers()->removeInactive();
    session.reset();
    if (FINISHED->external && bridge && !g_pSessionLockManager->isSessionLocked())
        (void)bridge->emit({4, FINISHED->window, 0.0, 0.0, 0.0, 0.0});
}

void ElasticDrag::release(const CBox& target) {
    if (!session || !session->held) return;
    damage();
    edgeClear();
    const auto NOW = Time::steadyNow();
    session->dropLift = session->lift(NOW);
    session->dropVelocity = session->velocity * ElasticMath::decay(std::chrono::duration<double, std::milli>(NOW - session->lastMotion).count(), Style::value("settle"));
    session->displayed = session->box(NOW);
    session->released = target;
    session->dropped = NOW;
    session->held = false;
    Animation::mgr()->requestTick();
}

bool ElasticDrag::suppressed(PHLWINDOW window) {
    return session && session->alive && session->window.lock() == window;
}

bool ElasticDrag::capturingOverview() { return captureDepth > 0; }

void ElasticDrag::paint(Render::CRenderContext& ctx, PHLMONITOR monitor) {
    if (!session || ctx.m_renderingSnapshot || ctx.m_renderingCapture || ctx.m_mode != Render::RENDER_MODE_NORMAL) return;
    const auto W = session->window.lock();
    if (!usable(W)) return;
    edgePaint(ctx, monitor);
    WindowMotion::paintCarried(ctx, W, monitor);
}

void ElasticDrag::init(HANDLE plugin) {
    handle = plugin;
    Style::init(handle);
    if (!WindowMotion::available()) return;
    for (const auto& fn : HyprlandAPI::findFunctionsByName(handle, "dragBegin"))
        if (fn.demangled.starts_with("Layout::Supplementary::CDragStateController::dragBegin("))
            beginHook = HyprlandAPI::createFunctionHook(handle, fn.address, (void*)begin);
    if (!beginHook || !beginHook->hook()) {
        std::cerr << "[windows] Elastic drag hook unavailable; ordinary movement retained\n";
        if (beginHook) HyprlandAPI::removeFunctionHook(handle, beginHook);
        beginHook = nullptr;
        return;
    }
    edgeInit();
    const auto& DRAG = g_layoutManager->dragController();
    listeners.emplace_back(DRAG->m_events.motion.listen(nativeMotion));
    listeners.emplace_back(DRAG->m_events.ended.listen(ended));
    auto& events = Event::bus()->m_events;
    listeners.emplace_back(events.tick.listen(tick));
    listeners.emplace_back(events.render.preChecks.listen([](PHLMONITOR m) {
        if (session && g_pSessionLockManager->isSessionLocked()) clear();
        if (session) m->m_solitaryClient.reset();
    }));
    listeners.emplace_back(events.render.stage.listen([](const Event::SRenderStageEvent& e) {
        if (e.stage == RENDER_LAST_MOMENT && e.context) paint(e.context->get(), e.monitor);
    }));
    listeners.emplace_back(events.window.close.listen([](PHLWINDOW w) { if (suppressed(w)) clear(); }));
    listeners.emplace_back(events.window.moveToWorkspace.listen([](PHLWINDOW w, PHLWORKSPACE ws) {
        if (suppressed(w) && ws && ws->type() == Workspace::eWorkspaceType::SPECIAL) clear();
    }));
    listeners.emplace_back(events.monitor.removed.listen([](PHLMONITOR m) { if (session && session->monitor.lock() == m) clear(); }));
    listeners.emplace_back(events.config.preReload.listen([] { clear(); }));
    listeners.emplace_back(events.config.props_refreshed.listen([](bool) { if (session && !Style::enabled()) clear(); }));
    listeners.emplace_back(events.input.keyboard.key.listen([](IKeyboard::SKeyEvent e, Event::SCallbackInfo& info) {
        if (e.keycode != KEY_ESC || e.state != WL_KEYBOARD_KEY_STATE_PRESSED || !session || !session->held || session->external) return;
        g_layoutManager->endDragTarget();
        info.cancelled = true;
    }));
    using E = Event::CEventBus::CCustomEvent;
    bridge = makeShared<E>("windows.elasticDrag", std::vector<E::eType>{E::TYPE_INT, E::TYPE_WINDOW, E::TYPE_DOUBLE, E::TYPE_DOUBLE, E::TYPE_DOUBLE, E::TYPE_DOUBLE});
    if (auto result = Event::bus()->addPluginEvent(bridge); !result) throw std::runtime_error(result.error());
    listeners.emplace_back(bridge->m_event.listen(external));
}

void ElasticDrag::exit() {
    clear();
    listeners.clear();
    edgeExit();
    if (bridge) (void)Event::bus()->removePluginEvent(bridge->m_name);
    bridge.reset();
    captureDepth = 0;
    pendingWindow.reset();
    if (beginHook) HyprlandAPI::removeFunctionHook(handle, beginHook);
    beginHook = nullptr;
}
