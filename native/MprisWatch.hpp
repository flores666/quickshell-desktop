#pragma once

#include <QDBusMessage>
#include <QHash>
#include <QObject>
#include <QPointer>
#include <QSet>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

// Recover Quickshell 0.3's failed initial MPRIS reads through its existing
// watcher. No second player model, protocol implementation or periodic retry.
class MprisWatch : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QObject* model READ model WRITE setModel NOTIFY modelChanged)

public:
    explicit MprisWatch(QObject* parent = nullptr);
    QObject* model() const { return m_model; }
    void setModel(QObject* model);

signals:
    void modelChanged();

protected:
    bool eventFilter(QObject* watched, QEvent* event) override;

private slots:
    void readFailed();
    void propertiesChanged(const QString& interface, const QVariantMap& changed,
                           const QStringList& invalidated, const QDBusMessage& message);

private:
    struct Pending { QPointer<QObject> player; QString owner; };
    void observe();
    void schedule(QObject* player, const QString& owner = {});
    void recover();
    bool listed(const QString& address) const;
    QObject* latest(const QString& address) const;

    QPointer<QObject> m_model;
    QPointer<QObject> m_watcher;
    QSet<QObject*> m_observed;
    QSet<QObject*> m_failed;
    QSet<QObject*> m_signaled;
    QHash<QString, Pending> m_pending;
    int m_generation = 0;
    bool m_scanQueued = false;
    bool m_recoveryQueued = false;
};
