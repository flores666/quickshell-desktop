pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/*!
    earlyoom's command line as the RAM tab reads and writes it: the four
    thresholds and the two lists, `--avoid` and `--prefer`, out of
    EARLYOOM_ARGS and back, every other option kept where it was.

    The file goes through systemd twice before earlyoom sees it.
    EnvironmentFile= reads backslashes inside the quotes, and `$EARLYOOM_ARGS`
    in ExecStart= is split at whitespace with no regard for quotes, so a list
    is written with neither: each name escaped with bracket expressions, a
    space as `[[:space:]]`, the names as one word, `^(a|b)$`. earlyoom
    matches a list against a process's name (its comm), searching, as a POSIX
    extended expression.

    A list may hold more than names: whatever was written there by hand and
    is not a name in that form is kept as written (`avoidExtra`,
    `preferExtra`), another alternative after the names, so the RAM tab
    never rewrites what it cannot read.
*/
Singleton {
    id: root

    /*! earlyoom's own, where its command line says nothing. */
    readonly property var defaults: ({
        memTerm: 10, memKill: 5, swapTerm: 10, swapKill: 5,
        avoid: [], prefer: [], avoidExtra: "", preferExtra: "", rest: []
    })

    /*! What a bracket expression must hold for the character to be itself. */
    readonly property string special: ".[]()*+?{}|$"

    /*! The config in EARLYOOM_ARGS: the thresholds, each list's names and
        what else it holds, and `rest`, every other word. */
    function parse(args: string): var {
        const config = Object.assign({}, root.defaults, { rest: [] });
        const words = args.trim().split(/\s+/).filter(w => w !== "");
        for (let i = 0; i < words.length; ++i) {
            const eq = words[i].startsWith("--") ? words[i].indexOf("=") : -1;
            const option = eq < 0 ? words[i] : words[i].slice(0, eq);
            const value = () => eq < 0 ? (words[++i] ?? "") : words[i].slice(eq + 1);
            if (option === "-m" || option === "-s") {
                const [term, kill] = value().split(",").map(Number);
                const prefix = option === "-m" ? "mem" : "swap";
                config[prefix + "Term"] = term;
                config[prefix + "Kill"] = kill ?? term / 2;
            } else if (option === "--avoid" || option === "--prefer") {
                const read = root.read(value());
                config[option.slice(2)] = read.names;
                config[option.slice(2) + "Extra"] = read.extra;
            } else {
                config.rest.push(words[i]);
            }
        }
        return config;
    }

    /*! The config back as EARLYOOM_ARGS: `rest`, the thresholds, the lists. */
    function format(config: var): string {
        const words = config.rest.concat(["-m", config.memTerm + "," + config.memKill,
                                          "-s", config.swapTerm + "," + config.swapKill]);
        for (const list of ["avoid", "prefer"]) {
            const regex = root.regex(config, list);
            if (regex !== "")
                words.push("--" + list, regex);
        }
        return words.join(" ");
    }

    /*! One list as earlyoom gets it: the names, then whatever else. */
    function regex(config: var, list: string): string {
        const names = config[list];
        return [names.length > 0 ? "^(" + names.map(root.quote).join("|") + ")$" : "",
                config[list + "Extra"] ?? ""].filter(r => r !== "").join("|");
    }

    /*! Names a list can hold: no bracket expression matches `\`, `"` or `^`
        alone without a backslash, which the file would read itself. */
    function listable(name: string): bool {
        return name !== "" && !/[\\"^\n]/.test(name);
    }

    function quote(name: string): string {
        return Array.from(name).map(c => c === " " ? "[[:space:]]"
            : c === "]" ? "[]]"
            : root.special.includes(c) ? "[" + c + "]" : c).join("");
    }

    /*! A list's names, from each top-level alternative of the form `quote`
        and `regex` write, and the other alternatives as written. */
    function read(regex: string): var {
        const names = [];
        const extra = [];
        for (const alternative of root.split(regex)) {
            const inner = alternative.startsWith("^(") && alternative.endsWith(")$")
                ? root.split(alternative.slice(2, -2)).map(root.unquote) : [null];
            if (inner.includes(null))
                extra.push(alternative);
            else
                names.push(...inner);
        }
        return { names, extra: extra.join("|") };
    }

    /*! An expression's top-level alternatives. */
    function split(regex: string): var {
        const parts = [""];
        let depth = 0;
        for (let i = 0; i < regex.length; ++i) {
            const c = regex[i];
            if (c === "[") {
                const end = root.bracketEnd(regex, i);
                parts[parts.length - 1] += regex.slice(i, end + 1);
                i = end;
                continue;
            }
            if (c === "|" && depth === 0) {
                parts.push("");
                continue;
            }
            depth += c === "(" ? 1 : c === ")" ? -1 : 0;
            parts[parts.length - 1] += c;
        }
        return parts.filter(p => p !== "");
    }

    /*! Where the bracket expression opening at `i` closes: a `]` straight
        after the opening one is its content, as is a `[:class:]`. */
    function bracketEnd(text: string, i: int): int {
        let j = i + 1;
        if (text[j] === "]")
            ++j;
        while (j < text.length && text[j] !== "]") {
            if (text[j] === "[" && text[j + 1] === ":")
                j = text.indexOf(":]", j + 2) + 1 || text.length;
            ++j;
        }
        return j;
    }

    /*! The name `quote` made `part` from, or null if it made no name. */
    function unquote(part: string): var {
        let name = "";
        for (let i = 0; i < part.length; ++i) {
            if (part[i] !== "[") {
                if (root.special.includes(part[i]))
                    return null;
                name += part[i];
                continue;
            }
            const end = root.bracketEnd(part, i);
            const inner = part.slice(i + 1, end);
            if (inner === "[:space:]")
                name += " ";
            else if (inner.length === 1)
                name += inner;
            else
                return null;
            i = end;
        }
        return name;
    }

    /*! earlyoom's test of a list against a name: a search. An expression
        JavaScript cannot read matches nothing. */
    function matches(regex: string, name: string): bool {
        return root.matcher(regex)(name);
    }

    /*! The same test, compiled once for many names. */
    function matcher(regex: string): var {
        if (regex === "")
            return () => false;
        try {
            const compiled = new RegExp(root.javascript(regex));
            return name => compiled.test(name);
        } catch (e) {
            return () => false;
        }
    }

    readonly property var classes: ({
        space: "\\s", digit: "\\d", alpha: "a-zA-Z", alnum: "a-zA-Z0-9", upper: "A-Z", lower: "a-z"
    })

    /*! A POSIX extended expression as JavaScript reads one: inside a bracket
        expression a backslash, `[` or `]` is itself in POSIX and has to be
        escaped for JavaScript (to which `[]` is an empty class), and a named
        class is spelled out. */
    function javascript(regex: string): string {
        let js = "";
        for (let i = 0; i < regex.length; ++i) {
            if (regex[i] !== "[") {
                js += regex[i];
                continue;
            }
            const end = root.bracketEnd(regex, i);
            const inner = regex.slice(i + 1, end);
            let out = "";
            for (let j = 0; j < inner.length; ++j) {
                if (inner.startsWith("[:", j)) {
                    const close = inner.indexOf(":]", j);
                    out += root.classes[inner.slice(j + 2, close)] ?? "";
                    j = close + 1;
                } else {
                    out += "]\\[".includes(inner[j]) ? "\\" + inner[j] : inner[j];
                }
            }
            js += "[" + out + "]";
            i = end;
        }
        return js;
    }
}
