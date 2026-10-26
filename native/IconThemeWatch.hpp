#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

// Qt's icon themes, read again whenever one changes on disk.
//
// Qt reads each theme's index and icon-theme.cache once and keeps them for the
// life of the process (QIconLoader's themeList), so an icon installed after
// the shell started, a new application's, was not found until a restart. This
// watches every directory under the icon search paths, where an install's
// last step renames a theme's new cache into place, and on a change has Qt
// drop what it read; `revision` turns over for whatever resolves icons by
// name to ask again.
class IconThemeWatch : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)

public:
    explicit IconThemeWatch(QObject* parent = nullptr);

    int revision() const { return m_revision; }

signals:
    void revisionChanged();

private:
    void watch();
    void reread();

    QFileSystemWatcher m_watcher;
    QTimer m_settle;
    int m_revision = 0;
};
