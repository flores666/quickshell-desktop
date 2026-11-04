pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/services"

Item {
    id: root
    readonly property string directory: Quickshell.env("TEST_BIN")
    Check { id: check }
    Command { id: sh }
    FileWait { id: file }

    Component.onCompleted: {
        if (root.directory === "") {
            check.report("private fixtures required", false, "run tools/test.sh");
            check.done(); return;
        }
        sh.run('python3 "$1" screenshot',
            [Qt.resolvedUrl("ServiceFixtures.py").toString().replace("file://", "")], () => {
                Screenshot.capture();
                Screenshot.capture();
                file.until(root.directory + "/saved", text => text.trim().split("\n").length === 2, text => {
                    const paths = text.trim().split("\n");
                    check.equal("two captures complete", paths.length, 2);
                    check.equal("same-second captures reserve distinct paths", new Set(paths).size, 2);
                    sh.run('for f do test "$(cat "$f")" = "completed image" || exit 1; done; echo complete', paths, out => {
                        check.equal("both saved images are complete", out.trim(), "complete");
                        // A region cancelled after reserving a file removes it.
                        Screenshot.run('printf %s "$f" > "$TEST_BIN/cancelled"; false', 0);
                        file.until(root.directory + "/cancelled", path => path !== "", path => {
                            file.until(path, contents => contents === "", () => {
                                sh.run('find "$1/pictures/Screenshots" -type f | wc -l; wc -l < "$1/saved"',
                                    [root.directory], counts => {
                                        check.equal("cancellation leaves two images and two notifications", counts.trim().split(/\s+/).join(" "), "2 2");
                                        check.done();
                                    });
                            });
                        });
                    });
                });
            });
    }
}
