import { watch } from "tilia";
import { expect } from "vitest";
import { Given, toRecords, type Context } from "vitest-bdd";
import type { Claim, Status } from "../src/app/claim";
import type { Tab } from "../src/app/features/claims/type";
import { makeWorld, type Pane, type World } from "../src/world";

// Server latency is 1ms in tests; flush lets in-flight round trips settle.
const flush = () => new Promise((resolve) => setTimeout(resolve, 20));
const wait = (seconds: number) => new Promise((resolve) => setTimeout(resolve, seconds * 1000));

Given(
  "a claims office with adjusters {string} and {string}",
  ({ And, When, Then }: Context, first: string, second: string) => {
    let world: World;
    const panes: Record<string, Pane> = {};

    const pane = (name: string): Pane => {
      const found = panes[name];
      if (!found) throw new Error(`Unknown adjuster "${name}"`);
      return found;
    };

    const rows = (p: Pane): Claim[] => {
      const list = p.app.claims.list;
      if (typeof list === "string") throw new Error(`Expected loaded claims, got "${list}"`);
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

    And("the office sets polling truth refresh to {number} seconds", async (seconds: number) => {
      world.configure({ refresh: seconds });
      await flush();
    });

    And("the office sets live truth refresh to {number} seconds", async (seconds: number) => {
      world.configure({ liveRefresh: seconds });
      await flush();
    });

    And("the office sets query expiration to {number} seconds", async (seconds: number) => {
      world.configure({ gc: seconds });
      await flush();
    });

    And("the office sets network latency to {number} milliseconds", async (milliseconds: number) => {
      world.configure({ latency: milliseconds });
      await flush();
    });

    When("{string} opens their claims", async (name: string) => {
      const p = pane(name);
      p.app.claims.filter("mine");
      watch(
        () => p.app.claims.list,
        () => {}
      );
      await flush();
    });

    When("{string} opens the {string} claims", async (name: string, tab: string) => {
      const p = pane(name);
      p.app.claims.filter(tab as Tab);
      watch(
        () => p.app.claims.list,
        () => {}
      );
      await flush();
    });

    When("{string} goes offline", (name: string) => {
      pane(name).network.online = false;
    });

    When("{string} comes back online", async (name: string) => {
      pane(name).network.online = true;
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

    When("{string} removes claim {string}", async (name: string, id: string) => {
      const p = pane(name);
      p.app.claims.remove(claim(p, id));
      await flush();
    });

    When("{string} restarts the app", async (name: string) => {
      pane(name).reload();
      await flush();
    });

    When("{number} seconds pass", async (seconds: number) => {
      await wait(seconds);
    });

    When("the scheduler ticks", async () => {
      for (const p of world.panes) p.app.tick();
      await flush();
    });

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

    Then("{string} no longer sees claim {string}", (name: string, id: string) => {
      expect(rows(pane(name)).find((c) => c.id === id)).toBeUndefined();
    });

    Then("{string} has one change waiting to sync", (name: string) => {
      expect(pane(name).app.claims.pending).toBe(1);
    });

    Then("{string} has no changes waiting to sync", (name: string) => {
      expect(pane(name).app.claims.pending).toBe(0);
    });

    Then("{string} is refused with {string}", (name: string, message: string) => {
      const rejected = pane(name).app.claims.rejected;
      expect(rejected.length).toBe(1);
      expect(rejected[0].message).toBe(message);
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

    Then("polling truth refresh is {number} seconds", (seconds: number) => {
      expect(world.settings.refresh).toBe(seconds);
    });

    Then("live truth refresh is {number} seconds", (seconds: number) => {
      expect(world.settings.liveRefresh).toBe(seconds);
    });

    Then("query expiration is {number} seconds", (seconds: number) => {
      expect(world.settings.gc).toBe(seconds);
    });

    Then("network latency is {number} milliseconds", (milliseconds: number) => {
      expect(world.settings.latency).toBe(milliseconds);
      expect(world.server.latency).toBe(milliseconds);
    });
  }
);
