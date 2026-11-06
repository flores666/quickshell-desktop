pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/components"
import "root:/services"

// The same AppIcon must redraw when its name exists in both variants. Lookup
// alone cannot prove this: the icon provider URL may resolve while its old
// pixels remain cached. Only tools/test.sh's private themes are written here.
Item {
    id: root

    Check { id: check }
    Command { id: sh }
    Until { id: ready }

    property bool started: false
    property var capture: null
    property int expected: 0
    property var next: null
    readonly property string icons: Quickshell.env("XDG_DATA_HOME") + "/icons"
    readonly property string charcoal: "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAAEklEQVR4nGOQkJD4j4wZSBcAAKGaFHHOqTTIAAAAAElFTkSuQmCC"
    readonly property string white: "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAAEklEQVR4nGP48OHDf2TMQLoAABc0PPGQ/86sAAAAAElFTkSuQmCC"

    PanelWindow {
        implicitWidth: 64
        implicitHeight: 64
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "shell-icon-render-test"

        AppIcon {
            id: icon
            anchors.centerIn: parent
            size: 32
            optical: true
            source: root.started ? "shell-test-same-name" : ""
        }

        Canvas {
            id: pixels
            width: icon.size
            height: icon.size
            opacity: 0

            onImageLoaded: pixels.requestPaint()
            onPaint: {
                if (root.capture === null || !pixels.isImageLoaded(root.capture.url))
                    return;
                const context = pixels.getContext("2d");
                context.clearRect(0, 0, pixels.width, pixels.height);
                context.drawImage(root.capture.url, 0, 0, pixels.width, pixels.height);
                const rgba = context.getImageData(pixels.width / 2, pixels.height / 2, 1, 1).data;
                check.equal("rendered red channel matches " + root.expected, rgba[0], root.expected);
                check.equal("rendered green channel matches " + root.expected, rgba[1], root.expected);
                check.equal("rendered blue channel matches " + root.expected, rgba[2], root.expected);
                check.equal("rendered icon remains opaque", rgba[3], 255);
                pixels.unloadImage(root.capture.url);
                root.capture = null;
                const then = root.next;
                root.next = null;
                then();
            }
        }
    }

    function select(theme: string, value: int, then: var): void {
        root.expected = value;
        root.next = then;
        IconThemes.watch.selectTheme(theme);
        Qt.callLater(() => ready.until(IconShapes.revisionChanged,
            () => icon.shape !== null && !icon.usingFallback,
            ok => {
                check.report(theme + ": artwork is ready", ok);
                if (!ok) {
                    IconThemes.watch.selectTheme(IconThemes.themeName);
                    check.done();
                    return;
                }
                if (!icon.grabToImage(result => {
                    root.capture = result;
                    pixels.loadImage(result.url);
                    if (pixels.isImageLoaded(result.url))
                        pixels.requestPaint();
                })) {
                    check.report("the displayed icon can be captured", false, "window is not mapped");
                    check.done();
                }
            }));
    }

    function begin(): void {
        if (root.started)
            return;
        const ours = Quickshell.shellPath("tests").replace(/\/tree\/tests$/, "/data");
        if (Quickshell.env("XDG_DATA_HOME") !== ours) {
            check.report("the tests' own data directory", false, "got " + Quickshell.env("XDG_DATA_HOME"));
            check.done();
            return;
        }
        root.started = true;
        sh.run(`for variant in Conflux ShellTestAlternate; do
                    target="$1/$variant"
                    mkdir -p "$target/48x48/apps"
                    printf '[Icon Theme]\\nName=Render fixture\\nInherits=hicolor\\nDirectories=48x48/apps\\n[48x48/apps]\\nSize=48\\nType=Fixed\\n' > "$target/index.theme"
                    data="$2"
                    [ "$variant" = ShellTestAlternate ] && data="$3"
                    printf %s "$data" | base64 -d > "$target/48x48/apps/shell-test-same-name.png"
                    gtk-update-icon-cache -q -f -t "$target"
                done`, [root.icons, root.charcoal, root.white], () => {
            root.select("Conflux", 24, () => root.select("ShellTestAlternate", 240, () => root.select("Conflux", 24, () => {
                IconThemes.watch.selectTheme(IconThemes.themeName);
                check.done();
            })));
        });
    }

    Connections {
        target: Settings
        function onReadyChanged(): void { if (Settings.ready) root.begin(); }
    }

    Component.onCompleted: if (Settings.ready) root.begin()
}
