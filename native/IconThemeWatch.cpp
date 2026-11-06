#include "IconThemeWatch.hpp"

#include <QDir>
#include <QIcon>
#include <QQmlEngine>
#include <QQuickImageProvider>
#include <atomic>
#include <mutex>

namespace {
// A QML reload creates another watch in the same process. Never reuse an old
// cache identity, even before the new watch has selected its first theme.
std::atomic<quint64> generation{0};
// Qt may render a provider image on its worker while the GUI selects a theme.
// Its theme caches must not be cleared until that render has finished.
std::mutex themeAccess;

class IconImages final : public QQuickImageProvider {
public:
    explicit IconImages(QQuickImageProvider* source)
        : QQuickImageProvider(Pixmap, source->flags()), m_source(source) {}

    QPixmap requestPixmap(const QString& id, QSize* size, const QSize& requested) override {
        const std::lock_guard lock(themeAccess);
        const auto slash = id.indexOf(u'/');
        return slash < 0 ? QPixmap() : m_source->requestPixmap(id.sliced(slash + 1), size, requested);
    }

private:
    // Both providers belong to this engine; Quickshell's icon provider stays
    // registered for its lifetime. Preserve its path/fallback query semantics.
    QQuickImageProvider* const m_source;
};
}

IconThemeWatch::IconThemeWatch(QObject* parent)
    : QObject(parent), m_generation(++generation) {
    // An install rewrites several themes' caches, each in a few steps: the
    // themes are read again once it has settled.
    m_settle.setSingleShot(true);
    m_settle.setInterval(250);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, &m_settle,
            qOverload<>(&QTimer::start));
    connect(&m_settle, &QTimer::timeout, this, &IconThemeWatch::reread);
    watch();
}

void IconThemeWatch::selectTheme(const QString& name) {
    {
        const std::lock_guard lock(themeAccess);
        if (name.isEmpty() || QIcon::themeName() == name)
            return;
        QIcon::setThemeName(name);
    }
    reread();
}

QString IconThemeWatch::imageSource(const QString& source) {
    const QString prefix = QStringLiteral("image://icon/");
    if (!source.startsWith(prefix))
        return source;
    auto* engine = qmlEngine(this);
    auto* provider = engine ? qobject_cast<QQuickImageProvider*>(engine->imageProvider(QStringLiteral("icon"))) : nullptr;
    if (!provider || provider->imageType() != QQmlImageProviderBase::Pixmap)
        return source;
    if (!engine->imageProvider(QStringLiteral("desktop-icons")))
        engine->addImageProvider(QStringLiteral("desktop-icons"), new IconImages(provider));
    return QStringLiteral("image://desktop-icons/%1/%2").arg(m_generation).arg(source.sliced(prefix.size()));
}

bool IconThemeWatch::iconAvailable(const QString& name) {
    // QIcon's availability lookup also updates its shared icon-engine cache.
    const std::lock_guard lock(themeAccess);
    return !QIcon::fromTheme(name).isNull();
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
    {
        const std::lock_guard lock(themeAccess);
        QIcon::setThemeSearchPaths(QIcon::themeSearchPaths());
        watch();
    }
    m_generation = ++generation;
    ++m_revision;
    emit revisionChanged();
}
