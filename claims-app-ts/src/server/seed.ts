import type { Claim } from "../app/claim";

export function seed(): Claim[] {
  return [
    row("CLM-1041", "M. Rochat", "Water damage", "Lausanne", "new", "", 0, ""),
    row("CLM-1042", "E. Baumann", "Hail", "Bern", "new", "", 0, ""),
    row("CLM-1043", "L. Favre", "Fire", "Geneva", "assigned", "Ana", 18500, "Kitchen and hallway affected."),
    row("CLM-1044", "K. Steiner", "Storm", "Zurich", "new", "", 0, ""),
    row("CLM-1045", "A. Conti", "Theft", "Lugano", "assigned", "Ben", 4200, "Inventory list pending."),
    row("CLM-1046", "J. Meyer", "Glass breakage", "Basel", "inspected", "Ben", 1200, "Shop front, single pane."),
    row("CLM-1047", "P. Dubois", "Water damage", "Fribourg", "closed", "Ana", 9800, "Settled with claimant."),
    row("CLM-1048", "S. Huber", "Vehicle collision", "Chur", "new", "", 0, ""),
  ];
}

function row(
  id: string,
  claimant: string,
  peril: string,
  city: string,
  status: Claim["status"],
  adjuster: string,
  estimate: number,
  notes: string
): Claim {
  return { id, claimant, peril, city, status, adjuster, estimate, notes, version: 1 };
}
