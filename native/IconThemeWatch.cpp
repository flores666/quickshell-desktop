#include "IconThemeWatch.hpp"

#include <QDir>
#include <QIcon>

IconThemeWatch::IconThemeWatch(QObject* parent) : QObject(parent) {
    // An install rewrites several themes' caches, each in a few steps: the
    // themes are read again once it has settled.
    m_settle.setSingleShot(true);
    m_settle.setInterval(250);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, &m_settle,
            qOverload<>(&QTimer::start));
    connect(&m_settle, &QTimer::timeout, this, &IconThemeWatch::reread);
    watch();
}

// Each search path, for a theme installed later, and each theme in it; the
// fallback paths (pixmaps) too, whose icons lie loose in them.
void IconThemeWatch::watch() {
    QStringList dirs;
    for (const QString& path : QIcon::themeSearchPaths() + QIcon::fallbackSearchPaths()) {
        const QDir dir(path);
        if (path.startsWith(u':') || !dir.exists())
            continue;
        dirs << dir.absolutePath();
        for (const QFileInfo& sub : dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot))
            dirs << sub.absoluteFilePath();
    }
    for (const QString& watched : m_watcher.directories())
        dirs.removeAll(watched);
    if (!dirs.isEmpty())
        m_watcher.addPaths(dirs);
}

void IconThemeWatch::reread() {
    // Setting the search paths is what has Qt drop the themes it has read
    // (QIconLoader::setThemeSearchPath clears themeList and bumps the key its
    // icons look themselves up again by); the same paths change nothing else.
    QIcon::setThemeSearchPaths(QIcon::themeSearchPaths());
    watch();
    ++m_revision;
    emit revisionChanged();
}
