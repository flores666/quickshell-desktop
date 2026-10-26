import QtQuick
import "root:/services"

/*!
    earlyoom's options as the RAM tab reads and writes them
    (EarlyOomArgs): the thresholds and the two lists out of EARLYOOM_ARGS and
    back, whatever else is there kept in its order, and a process name in a
    list matching that name alone, written so that systemd, which splits the
    variable at whitespace and reads backslashes in the file, hands earlyoom
    each option whole.
*/
Item {
    id: root

    Check {
        id: check
    }

    function same(name: string, actual: var, expected: var): void {
        check.equal(name, JSON.stringify(actual), JSON.stringify(expected));
    }

    readonly property string project: "-r 0 -m 10,5 -s 10,5"
        + " --avoid ^(Hyprland|Xwayland|qs|pipewire|wireplumber)$"
        + " --prefer ^(Web[[:space:]]Content|Isolated[[:space:]]Web[[:space:]]Co)$"

    Component.onCompleted: {
        check.attempt("nothing set: earlyoom's own", () => {
            const c = EarlyOomArgs.parse("");
            check.equal("nothing set: SIGTERM below memory", c.memTerm, 10);
            check.equal("nothing set: SIGKILL below memory", c.memKill, 5);
            check.equal("nothing set: SIGTERM below swap", c.swapTerm, 10);
            check.equal("nothing set: SIGKILL below swap", c.swapKill, 5);
            root.same("nothing set: no lists", [c.avoid, c.prefer, c.avoidExtra, c.preferExtra, c.rest], [[], [], "", "", []]);
        });

        check.attempt("the project's", () => {
            const c = EarlyOomArgs.parse(root.project);
            root.same("the project's: thresholds", [c.memTerm, c.memKill, c.swapTerm, c.swapKill], [10, 5, 10, 5]);
            root.same("the project's: avoid", c.avoid, ["Hyprland", "Xwayland", "qs", "pipewire", "wireplumber"]);
            root.same("the project's: prefer", c.prefer, ["Web Content", "Isolated Web Co"]);
            root.same("the project's: the rest", c.rest, ["-r", "0"]);
            check.equal("the project's: written back as it was", EarlyOomArgs.format(c), root.project);
        });

        check.attempt("SIGKILL defaults to half", () => {
            const c = EarlyOomArgs.parse("-m 20 -s 7.5");
            root.same("SIGKILL defaults to half", [c.memTerm, c.memKill, c.swapTerm, c.swapKill], [20, 10, 7.5, 3.75]);
        });

        check.attempt("--option=value", () => {
            const c = EarlyOomArgs.parse("--avoid=^(a)$ --prefer=^(b|c)$");
            root.same("--option=value: avoid", c.avoid, ["a"]);
            root.same("--option=value: prefer", c.prefer, ["b", "c"]);
        });

        check.attempt("the rest kept in order", () => {
            const c = EarlyOomArgs.parse("-n -r 60 -m 8,4 -g --sort-by-rss -N /usr/local/bin/hook");
            root.same("the rest kept in order", c.rest, ["-n", "-r", "60", "-g", "--sort-by-rss", "-N", "/usr/local/bin/hook"]);
            root.same("the rest kept in order: ours read", [c.memTerm, c.memKill], [8, 4]);
        });

        check.attempt("a hand-written regex", () => {
            const c = EarlyOomArgs.parse("--avoid (chrom|fire).*");
            root.same("a hand-written regex: no names", c.avoid, []);
            check.equal("a hand-written regex: kept", c.avoidExtra, "(chrom|fire).*");
            check.equal("a hand-written regex: written back as it was", EarlyOomArgs.format(c), "-m 10,5 -s 10,5 --avoid (chrom|fire).*");
            const mixed = EarlyOomArgs.parse("--prefer ^(qs|Web[[:space:]]Content)$|^(chrom.*)$|fire");
            root.same("names and more: the names", mixed.prefer, ["qs", "Web Content"]);
            check.equal("names and more: the rest kept", mixed.preferExtra, "^(chrom.*)$|fire");
            mixed.prefer.push("kitty");
            check.equal("names and more: a name added before the rest", EarlyOomArgs.format(mixed),
                "-m 10,5 -s 10,5 --prefer ^(qs|Web[[:space:]]Content|kitty)$|^(chrom.*)$|fire");
        });

        check.attempt("round trip", () => {
            const c = {
                memTerm: 12, memKill: 6, swapTerm: 20, swapKill: 10,
                avoid: ["Web Content", "a.b", "x(y)", "p+q|r", "[br]", "s$", "t*?{}"],
                prefer: [],
                avoidExtra: "",
                preferExtra: "",
                rest: ["-r", "0", "-n"]
            };
            const args = EarlyOomArgs.format(c);
            check.report("round trip: no backslash", !args.includes("\\"), args);
            check.report("round trip: no prefer option for an empty list", !args.includes("--prefer"), args);
            check.equal("round trip: one word per option", args.split(" ").length, 3 + 4 + 2);
            root.same("round trip: read back", EarlyOomArgs.parse(args), c);
        });

        check.attempt("a name matches itself alone", () => {
            const list = name => EarlyOomArgs.format({
                memTerm: 10, memKill: 5, swapTerm: 10, swapKill: 5, avoid: [name], prefer: [], rest: []
            }).split(" ").pop();
            check.equal("a.b: itself", EarlyOomArgs.matches(list("a.b"), "a.b"), true);
            check.equal("a.b: not axb", EarlyOomArgs.matches(list("a.b"), "axb"), false);
            check.equal("Web Content: itself", EarlyOomArgs.matches(list("Web Content"), "Web Content"), true);
            check.equal("Web Content: not WebxContent", EarlyOomArgs.matches(list("Web Content"), "WebxContent"), false);
            check.equal("x(y): itself", EarlyOomArgs.matches(list("x(y)"), "x(y)"), true);
            check.equal("[br]: itself", EarlyOomArgs.matches(list("[br]"), "[br]"), true);
            check.equal("[br]: not b", EarlyOomArgs.matches(list("[br]"), "b"), false);
            check.equal("qs: not qsx", EarlyOomArgs.matches(list("qs"), "qsx"), false);
            check.equal("a hand-written regex searches", EarlyOomArgs.matches("chrom", "chromium"), true);
            check.equal("a broken regex matches nothing", EarlyOomArgs.matches("(", "("), false);
        });

        check.attempt("listable", () => {
            check.equal("listable: a space", EarlyOomArgs.listable("Web Content"), true);
            check.equal("listable: a backslash", EarlyOomArgs.listable("a\\b"), false);
            check.equal("listable: a quote", EarlyOomArgs.listable("a\"b"), false);
            check.equal("listable: a caret", EarlyOomArgs.listable("a^b"), false);
            check.equal("listable: nothing", EarlyOomArgs.listable(""), false);
        });

        check.done();
    }
}
