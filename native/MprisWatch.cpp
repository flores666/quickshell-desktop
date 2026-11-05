#include "MprisWatch.hpp"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusReply>
#include <QEvent>
#include <utility>

namespace {
const QString path = QStringLiteral("/org/mpris/MediaPlayer2");
const QString playerInterface = QStringLiteral("org.mpris.MediaPlayer2.Player");
}

MprisWatch::MprisWatch(QObject* parent) : QObject(parent) {
    QDBusConnection::sessionBus().connect({}, path, QStringLiteral("org.freedesktop.DBus.Properties"),
        QStringLiteral("PropertiesChanged"), this,
        SLOT(propertiesChanged(QString,QVariantMap,QStringList,QDBusMessage)));
}

void MprisWatch::setModel(QObject* model) {
    if (m_model == model)
        return;
    if (m_watcher)
        m_watcher->removeEventFilter(this);
    for (auto* player : std::as_const(m_observed)) {
        disconnect(player, nullptr, this, nullptr);
        for (auto* child : player->children())
            disconnect(child, nullptr, this, nullptr);
    }
    ++m_generation;
    m_observed.clear();
    m_failed.clear();
    m_signaled.clear();
    m_pending.clear();
    m_scanQueued = m_recoveryQueued = false;
    m_model = model;
    m_watcher = nullptr;

    // These are Quickshell 0.3's registration slots, not a public API. Guard
    // the exact contract so another version degrades to ordinary discovery.
    auto* watcher = model ? model->parent() : nullptr;
    if (watcher && QByteArray(watcher->metaObject()->className()) == "qs::service::mpris::MprisWatcher"
        && model->metaObject()->indexOfProperty("values") >= 0
        && watcher->metaObject()->indexOfSlot("onServiceRegistered(QString)") >= 0
        && watcher->metaObject()->indexOfSlot("onServiceUnregistered(QString)") >= 0) {
        m_watcher = watcher;
        watcher->installEventFilter(this);
        observe();
    } else if (model) {
        qWarning("MprisWatch: unsupported Quickshell watcher; using ordinary MPRIS discovery");
    }
    emit modelChanged();
}

bool MprisWatch::listed(const QString& address) const {
    if (m_model) {
        const auto players = m_model->property("values").value<QObjectList>();
        for (auto* player : players)
            if (player && player->property("dbusName").toString() == address)
                return true;
    }
    return false;
}

QObject* MprisWatch::latest(const QString& address) const {
    if (!m_watcher)
        return nullptr;
    // A retired object can remain a child until deleteLater runs. Only the
    // newest instance of an address is eligible for recovery.
    const auto children = m_watcher->children();
    for (auto it = children.crbegin(); it != children.crend(); ++it)
        if ((*it)->property("dbusName").toString() == address)
            return *it;
    return nullptr;
}

void MprisWatch::observe() {
    if (!m_watcher)
        return;
    const auto children = m_watcher->children();
    for (auto* player : children) {
        const QString address = player->property("dbusName").toString();
        if (!address.startsWith(QStringLiteral("org.mpris.MediaPlayer2.")) || m_observed.contains(player))
            continue;
        m_observed.insert(player);
        connect(player, &QObject::destroyed, this, [this, player]() {
            m_observed.remove(player);
            m_failed.remove(player);
            m_signaled.remove(player);
        });
        for (auto* child : player->children()) {
            if (child->metaObject()->indexOfSignal("getAllFailed(QDBusError)") >= 0)
                connect(child, SIGNAL(getAllFailed(QDBusError)), this, SLOT(readFailed()));
        }
        // Attaching after an earlier failure: signals can have filled the
        // hidden object even though GetAll never admitted it to the model.
        if (!listed(address) && !player->property("metadata").toMap().isEmpty()) {
            m_failed.insert(player);
            schedule(player);
        }
    }
}

bool MprisWatch::eventFilter(QObject* watched, QEvent* event) {
    if (watched == m_watcher && event->type() == QEvent::ChildAdded && !m_scanQueued) {
        m_scanQueued = true;
        const int generation = m_generation;
        // ChildAdded arrives during QObject's base constructor. Observe only
        // after the player and its property groups have been constructed.
        QMetaObject::invokeMethod(this, [this, generation]() {
            if (generation != m_generation) return;
            m_scanQueued = false;
            observe();
        }, Qt::QueuedConnection);
    }
    return QObject::eventFilter(watched, event);
}

void MprisWatch::readFailed() {
    auto* player = sender() ? sender()->parent() : nullptr;
    if (!m_observed.contains(player) || listed(player->property("dbusName").toString()))
        return;
    m_failed.insert(player);
    if (m_signaled.contains(player))
        schedule(player);
}

void MprisWatch::propertiesChanged(const QString& interface, const QVariantMap&,
                                  const QStringList&, const QDBusMessage& message) {
    if (!m_watcher || (interface != playerInterface && interface != QStringLiteral("org.mpris.MediaPlayer2")))
        return;
    const auto players = m_observed;
    for (auto* player : players) {
        const QString address = player->property("dbusName").toString();
        if (listed(address) || latest(address) != player)
            continue;
        const QDBusReply<QString> owner = QDBusConnection::sessionBus().interface()->serviceOwner(address);
        if (!owner.isValid() || owner.value() != message.service())
            continue;
        m_signaled.insert(player);
        if (m_failed.contains(player))
            schedule(player, owner.value());
    }
}

void MprisWatch::schedule(QObject* player, const QString& owner) {
    const QString address = player->property("dbusName").toString();
    if (latest(address) != player || listed(address))
        return;
    m_pending.insert(address, {player, owner});
    if (m_recoveryQueued)
        return;
    m_recoveryQueued = true;
    const int generation = m_generation;
    QMetaObject::invokeMethod(this, [this, generation]() {
        if (generation != m_generation) return;
        m_recoveryQueued = false;
        recover();
    }, Qt::QueuedConnection);
}

void MprisWatch::recover() {
    const auto pending = std::exchange(m_pending, {});
    for (auto it = pending.cbegin(); it != pending.cend(); ++it) {
        const auto subject = it.value();
        if (!m_watcher || !subject.player || listed(it.key()) || latest(it.key()) != subject.player)
            continue;
        const QDBusReply<QString> owner = QDBusConnection::sessionBus().interface()->serviceOwner(it.key());
        if (!owner.isValid() || (!subject.owner.isEmpty() && subject.owner != owner.value()))
            continue;
        // Let Quickshell recreate its own player and read all properties.
        // No attempt repeats without another real readiness signal/failure.
        QMetaObject::invokeMethod(m_watcher, "onServiceUnregistered", Qt::DirectConnection, Q_ARG(QString, it.key()));
        QMetaObject::invokeMethod(m_watcher, "onServiceRegistered", Qt::DirectConnection, Q_ARG(QString, it.key()));
        observe();
    }
}
