import { observe } from "tilia";
import { expect } from "vitest";
import { Given, toRecords, type Context } from "vitest-bdd";
import type { Rejection } from "@tilia/query";
import type { Claim, Status } from "../src/app/claim";
import type { Tab } from "../src/app/features/claims/type";
import { makeWorld, type Pane, type World } from "../src/world";

// Server latency is 1ms in tests; flush lets in-flight round trips settle.
const flush = () => new Promise((resolve) => setTimeout(resolve, 50));

const duration = (value: number, unit: string) => {
  switch (unit) {
    case "seconds":
      return value * 1000;
    case "minutes":
      return value * 60 * 1000;
    case "days":
      return value * 24 * 60 * 60 * 1000;
    default:
      throw new Error(`Unknown time unit "${unit}"`);
  }
};

Given(
  "a claims office with adjusters {string} and {string}",
  ({ And, When, Then }: Context, first: string, second: string) => {
    let world: World;
    let startedAt: number;
    const panes: Record<string, Pane> = {};
    const observers: (() => void)[] = [];
    const restarts: Record<string, Promise<void>> = {};

    const pane = (name: string): Pane => {
      const found = panes[name];
      if (!found) throw new Error(`Unknown adjuster "${name}"`);
      return found;
    };

    const rows = (p: Pane): Claim[] => {
      const list = p.app.claims.list;
      if (typeof list === "string" || list.state !== "loaded") {
        throw new Error(`Expected loaded claims, got ${JSON.stringify(list)}`);
      }
      return list.data;
    };

    const claim = (p: Pane, id: string): Claim => {
      const found = rows(p).find((c) => c.id === id);
      if (!found) throw new Error(`Claim "${id}" not visible for "${p.user.name}"`);
      return found;
    };

    const office = (id: string): Claim => {
      const found = world.server.rows[id];
      if (!found) throw new Error(`Claim "${id}" not on file`);
      return found;
    };

    const observePane = (p: Pane) => {
      observers.push(
        observe(() => {
          const list = p.app.claims.list;
          if (typeof list === "object" && list.state === "loaded") list.data.length;
        })
      );
    };

    And("the claims on file are", async (table: string[][]) => {
      const claims = toRecords(table).map(
        (row): Claim => ({
          id: row.id,
          claimant: row.claimant,
          peril: row.peril,
          city: row.city,
          status: row.status as Status,
          adjuster: row.adjuster,
          estimate: Number(row.estimate),
          notes: "",
          version: 1,
        })
      );
      world = makeWorld(claims);
      startedAt = world.clock.value;
      world.configure({ latency: 1 });
      for (const p of world.panes) panes[p.user.name] = p;
      pane(first);
      pane(second);
      await flush();
    });

    When("the office switches to live updates", async () => {
      world.setLive(true);
      await flush();
    });

    And("the office sets network latency to {number} milliseconds", async (milliseconds: number) => {
      world.configure({ latency: milliseconds });
      await flush();
    });

    When("{string} opens their claims", async (name: string) => {
      const p = pane(name);
      p.app.claims.filter("mine");
      observePane(p);
      await flush();
    });

    When("{string} opens the {string} claims", async (name: string, tab: string) => {
      const p = pane(name);
      p.app.claims.filter(tab as Tab);
      observePane(p);
      await flush();
    });

    When("{string} goes offline", (name: string) => {
      pane(name).network.online.value = false;
    });

    When("{string} comes back online", async (name: string) => {
      pane(name).network.online.value = true;
      await flush();
    });

    When("{string} takes claim {string}", async (name: string, id: string) => {
      const p = pane(name);
      p.app.claims.take(claim(p, id));
      await flush();
    });

    When(
      "{string} records an inspection on claim {string} with estimate {number} and notes {string}",
      async (name: string, id: string, estimate: number, notes: string) => {
        const p = pane(name);
        p.app.claims.edit(claim(p, id));
        const draft = p.app.claims.editing;
        if (!draft) throw new Error("Expected an editing draft");
        draft.status = "inspected";
        draft.estimate = estimate;
        draft.notes = notes;
        p.app.claims.commit();
        await flush();
      }
    );

    When(
      "{string} changes claim {string} field {string} to {string}",
      async (name: string, id: string, field: string, value: string) => {
        const p = pane(name);
        p.app.claims.edit(claim(p, id));
        const draft = p.app.claims.editing;
        if (!draft) throw new Error("Expected an editing draft");
        switch (field) {
          case "city":
            draft.city = value;
            break;
          case "notes":
            draft.notes = value;
            break;
          default:
            throw new Error(`Unsupported claim field "${field}"`);
        }
        p.app.claims.commit();
        await flush();
      }
    );

    When("{string} removes claim {string}", async (name: string, id: string) => {
      const p = pane(name);
      p.app.claims.remove(claim(p, id));
      await flush();
    });

    When("{string} restarts the app", async (name: string) => {
      await pane(name).reload();
      await flush();
    });

    When("{string} begins restarting the app", (name: string) => {
      restarts[name] = pane(name).reload();
    });

    When("{string} finishes restarting the app", async (name: string) => {
      const restart = restarts[name];
      if (!restart) throw new Error(`No restart in progress for "${name}"`);
      await restart;
      await flush();
    });

    When("{string} begins resolving the conflict for claim {string}", (name: string, id: string) => {
      const p = pane(name);
      const rejected = p.app.claims.rejected[0];
      if (!rejected) throw new Error("Expected a rejected change");
      const theirs = p.local.rows.get(id);
      if (!theirs) throw new Error(`Expected current claim "${id}"`);
      p.app.claims.resolve(rejected, theirs);
    });

    Then(
      "{string} resolves field {string} with theirs {string} and mine {string}",
      (name: string, field: string, theirs: string, mine: string) => {
        const resolution = pane(name).app.claims.resolution;
        if (!resolution) throw new Error("Expected a conflict resolution");
        expect(resolution.fields).toContain(field);
        expect(resolution.theirs[field as keyof Claim]).toBe(theirs);
        expect(resolution.mine[field as keyof Claim]).toBe(mine);
      }
    );

    When(
      "{string} changes the resolution field {string} to {string}",
      (name: string, field: string, value: string) => {
        const resolution = pane(name).app.claims.resolution;
        if (!resolution) throw new Error("Expected a conflict resolution");
        Object.assign(resolution.draft, { [field]: value });
      }
    );

    When("{string} saves the conflict resolution", async (name: string) => {
      pane(name).app.claims.saveResolution();
      await flush();
    });

    const advance = async (value: number, unit: string) => {
      world.advance(duration(value, unit));
      await flush();
    };
    When("the office advances time by {number} seconds", (value: number) => advance(value, "seconds"));
    When("the office advances time by {number} minutes", (value: number) => advance(value, "minutes"));
    When("the office advances time by {number} days", (value: number) => advance(value, "days"));

    Then("{string} sees claims {string}", (name: string, expected: string) => {
      const ids = rows(pane(name))
        .map((c) => c.id)
        .sort()
        .join(", ");
      expect(ids).toBe(expected);
    });

    Then("{string} sees claims in order {string}", (name: string, expected: string) => {
      const ids = rows(pane(name))
        .map((c) => c.id)
        .join(", ");
      expect(ids).toBe(expected);
    });

    Then("{string} adaptor calls include", (name: string, table: string[][]) => {
      const calls = pane(name).log.calls;
      for (const expected of toRecords(table)) {
        expect(
          calls.some(
            (call) =>
              call.tag === expected.tag &&
              call.name === expected.call &&
              (expected.direction === undefined ||
                (expected.direction === "reply" ? call.reply === true : call.reply !== true)) &&
              (expected.value === undefined ||
                (expected.value === "some" ? call.value !== undefined : call.value === undefined))
          )
        ).toBe(true);
      }
    });

    Then("{string} adaptor calls exclude", (name: string, table: string[][]) => {
      const calls = pane(name).log.calls;
      for (const expected of toRecords(table)) {
        expect(calls.some((call) => call.tag === expected.tag && call.name === expected.call)).toBe(false);
      }
    });

    Then("{string} adaptor calls are empty", (name: string) => {
      expect(pane(name).log.calls).toHaveLength(0);
    });

    Then("{string} client is reloading", (name: string) => {
      expect(pane(name).reloading).toBe(true);
    });

    Then("{string} client is running", (name: string) => {
      expect(pane(name).reloading).toBe(false);
    });

    const reads = (expected: number) => {
      expect(world.server.fetches).toBe(expected);
    };
    Then("the office has answered {number} read", reads);
    Then("the office has answered {number} reads", reads);

    const subs = (expected: number) => {
      expect(world.server.subs.length).toBe(expected);
    };
    Then("the office has {number} live subscription", subs);
    Then("the office has {number} live subscriptions", subs);

    Then("{string} sees claim {string} as {string}", (name: string, id: string, status: string) => {
      expect(claim(pane(name), id).status).toBe(status);
    });

    Then("{string} sees claim {string} assigned to {string}", (name: string, id: string, adjuster: string) => {
      const found = claim(pane(name), id);
      expect(found.status).toBe("assigned");
      expect(found.adjuster).toBe(adjuster);
    });

    Then(
      "{string} sees claim {string} field {string} as {string}",
      (name: string, id: string, field: string, expected: string) => {
        expect(claim(pane(name), id)[field as keyof Claim]).toBe(expected);
      }
    );

    Then("{string} no longer sees claim {string}", (name: string, id: string) => {
      expect(rows(pane(name)).find((c) => c.id === id)).toBeUndefined();
    });

    Then("{string} has one change waiting to sync", (name: string) => {
      expect(pane(name).app.claims.pending).toBe(1);
    });

    Then("{string} has no changes waiting to sync", (name: string) => {
      expect(pane(name).app.claims.pending).toBe(0);
    });

    Then("{string} has no rejected changes", (name: string) => {
      expect(pane(name).app.claims.rejected).toHaveLength(0);
    });

    Then("{string} has an update conflict for claim {string}", (name: string, id: string) => {
      const rejected = pane(name).app.claims.rejected;
      expect(rejected).toHaveLength(1);
      expect(rejected[0].TAG).toBe("UpdateConflict");
      if (rejected[0].TAG === "UpdateConflict") {
        expect(rejected[0]._1.id).toBe(id);
      }
    });

    Then("{string} is refused with {string}", (name: string, message: string) => {
      const rejected = pane(name).app.claims.rejected;
      expect(rejected.length).toBe(1);
      const first: Rejection<Claim> = rejected[0];
      switch (first.TAG) {
        case "CreateFailed":
        case "RemoveFailed":
          expect(first._1).toBe(message);
          break;
        case "UpdateFailed":
          expect(first._2).toBe(message);
          break;
        default:
          throw new Error(`Expected a failed write, got ${first.TAG}`);
      }
    });

    Then("the office shows claim {string} as {string}", (id: string, status: string) => {
      expect(office(id).status).toBe(status);
    });

    Then("the office shows claim {string} assigned to {string}", (id: string, adjuster: string) => {
      expect(office(id).status).toBe("assigned");
      expect(office(id).adjuster).toBe(adjuster);
    });

    Then("the office shows claim {string} with estimate {number}", (id: string, estimate: number) => {
      expect(office(id).estimate).toBe(estimate);
    });

    Then("the office shows claim {string} field {string} as {string}", (id: string, field: string, expected: string) => {
      expect(office(id)[field as keyof Claim]).toBe(expected);
    });

    Then(
      "the office marks claim {string} write by {string} and read by {string}",
      (id: string, writer: string, reader: string) => {
        const touch = world.server.touches[id];
        expect(touch).toBeDefined();
        expect(touch.write?.by).toBe(pane(writer).user.id);
        expect(touch.read?.by).toBe(pane(reader).user.id);
        expect(touch.write?.seq).toBe(touch.seq);
        expect(touch.read?.seq).toBe(touch.seq);
      }
    );

    Then("the office still shows claim {string}", (id: string) => {
      expect(world.server.rows[id]).toBeDefined();
    });

    Then("the office no longer shows claim {string}", (id: string) => {
      expect(world.server.rows[id]).toBeUndefined();
    });

    Then("fake time is {number} days after startup", (value: number) => {
      expect(world.clock.value).toBe(startedAt + duration(value, "days"));
    });

    Then("network latency is {number} milliseconds", (milliseconds: number) => {
      expect(world.settings.latency).toBe(milliseconds);
      expect(world.server.latency).toBe(milliseconds);
    });
  }
);
