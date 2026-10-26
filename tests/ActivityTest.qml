import QtQuick
import "root:/services"

/*!
    What has used each thing most over the last minute (Activity): a record
    of each sample that read the processes, and the ranking over those of the
    last `Usage.span` — a mean for what is used over time, the latest for
    what is held — a process kept until it falls out of the window, ended or
    not. Live, a watch's samples rank the busiest processes.
*/
Item {
    id: root

    Check {
        id: check
    }

    Until {
        id: until
    }

    function same(name: string, actual: var, expected: var): void {
        check.equal(name, JSON.stringify(actual), JSON.stringify(expected));
    }

    /*! Three samples a minute apart in all, as Activity records them: what
        each process used, only what was above 0, null for what a sample did
        not read. */
    readonly property var records: [
        { t: 0, names: { 1: "one", 2: "two" }, cpu: { 1: 10, 2: 30 }, gpu: null, io: { 2: 4096 },
          rss: null, connections: null },
        { t: 30, names: { 1: "one", 3: "three" }, cpu: { 1: 20, 3: 6 }, gpu: { 3: 50 }, io: {},
          rss: null, connections: null },
        { t: 60, names: { 1: "one", 3: "three", 4: "four" }, cpu: { 3: 3, 4: 9 }, gpu: { 3: 10 }, io: {},
          rss: { 1: 2000, 3: 1000, 4: 2000 }, connections: { 3: 2 } }
    ]

    function ranked(key: string, now: real, count: int): var {
        return Activity.rank(root.records, key, now, 60, count).map(e => [e.pid, e.name, e.value, e.now]);
    }

    /*! Each change of a binding to `top`, against the samples ranked. */
    property int changes: 0
    readonly property var busiest: Activity.top("cpu", 5)
    onBusiestChanged: root.changes++

    Component.onCompleted: {
        check.attempt("rank", () => {
            // 1: (10 + 20 + 0) / 3, quiet in the latest; 2: 30 / 3, ended;
            // 3: (0 + 6 + 3) / 3; 4: (0 + 0 + 9) / 3.
            root.same("cpu: the mean over the samples in the minute, best first, ties by pid",
                root.ranked("cpu", 60, 5),
                [[1, "one", 10, false], [2, "two", 10, false], [3, "three", 3, true], [4, "four", 3, true]]);
            check.equal("cpu: count respected", root.ranked("cpu", 60, 3).length, 3);
            root.same("cpu: an old record dropped, and with it a process that went quiet before",
                root.ranked("cpu", 61, 5), [[1, "one", 10, false], [3, "three", 4.5, true], [4, "four", 4.5, true]]);
            root.same("gpu: only over the samples that read it", root.ranked("gpu", 60, 5), [[3, "three", 30, true]]);
            root.same("io: bytes a second, a sample without counting 0", root.ranked("io", 60, 5),
                [[2, "two", 1365, false]]);
            root.same("rss: as it stands in the latest", root.ranked("rss", 60, 5),
                [[1, "one", 2000, true], [4, "four", 2000, true], [3, "three", 1000, true]]);
            root.same("connections: as they stand", root.ranked("connections", 60, 5), [[3, "three", 2, true]]);
            root.same("nothing in the window, nothing ranked", root.ranked("cpu", 200, 5), []);
            root.same("a key no sample read, nothing ranked", Activity.rank(root.records.slice(0, 1), "gpu", 0, 60, 5), []);
        });

        check.attempt("record", () => {
            const list = [
                { pid: 1, name: "one", cpu: 0, gpu: -1, io: -1, rss: 100, connections: -1 },
                { pid: 2, name: "two", cpu: 1.5, gpu: 2, io: 0, rss: 0, connections: 3 }
            ];
            root.same("record: what was above 0, a key read by none null", Activity.record(list, 12), {
                t: 12, names: { 1: "one", 2: "two" }, cpu: { 2: 1.5 }, gpu: { 2: 2 }, io: {},
                rss: { 1: 100 }, connections: { 2: 3 }
            });
        });

        check.attempt("live", () => {
            Processes.watch("activity", true);
            until.bound = 3000;
            // From here: the binding's first evaluations, as Activity is
            // made, are before.
            const revision = Activity.revision;
            const changes = root.changes;
            until.until(Activity.revisionChanged, () => Activity.top("cpu", 5).length > 0, ranked => {
                const top = Activity.top("cpu", 5);
                check.report("live: the busiest processes ranked", ranked && top.length <= 5
                    && top.every((e, i) => e.value > 0 && e.name !== "" && (i === 0 || top[i - 1].value >= e.value)),
                    JSON.stringify(top));
                const changed = root.changes - changes;
                check.report("live: a binding to top changes at most once a ranking",
                    changed > 0 && changed <= Activity.revision - revision,
                    changed + " changes, " + (Activity.revision - revision) + " rankings");
                check.equal("live: rss ranked as it stands", Activity.top("rss", 3).every(e => e.now), true);
                Processes.watch("activity", false);
                check.done();
            });
        });
    }
}
