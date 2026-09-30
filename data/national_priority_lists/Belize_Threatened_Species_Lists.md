# Belize Threatened Species - Compiled Lists

Compiled from three source documents:
1. **Threatened Tree Workshop Report** (Ya'axche Conservation Trust / Fauna & Flora, July 2023)
2. **Belize National Red List of Threatened Species - Mammals, Birds, Reptiles, Amphibians** (Belize Forest Department, 2025)
3. **National Threatened Avian Species - Belize** (Wildtracks / GIZ, 2020)

See `Belize_Threatened_Species_Table.csv` in this folder for the machine-readable version (one row per species x source).

---

## 1. Trees - Threatened Tree Workshop Report (2023)

Basis: **global IUCN Red List**, filtered to species confirmed present in Belize (not a Belize-specific rating scheme - the working national list used for tree conservation prioritization). 68 species total; workshop focused on the 25 CR+EN species.

- Critically Endangered: 2 species
- Endangered: 23 species
- Vulnerable: 29 species
- Near Threatened: 14 species

## 2. Fauna - Belize National Red List (Forest Department, 2025)

The current, authoritative **national** rating for mammals, birds, reptiles, and amphibians - 106 threatened species plus a Watch List. Ratings can diverge from global IUCN status in either direction (e.g. Jaguar is EN nationally but NT globally; several terns are CR nationally despite being globally LC).

- Critically Endangered: 15 species
- Endangered: 24 species
- Vulnerable: 33 species
- Watch List (NT/LC/DD, not individually disaggregated in the source): ~24 species

## 3. Birds - National Threatened Avian Species, Belize (Wildtracks / GIZ, 2020)

Precursor to the bird section of the 2025 national list above (same lead author, same methodology). Several species' national ratings shifted between 2020 and 2025.

---

## Notes on cross-document differences (for anyone re-deriving this table)

- The tree report is built on **global** IUCN ratings filtered for Belize occurrence; the 2025 fauna Red List is a genuinely **national** assessment that can diverge from global IUCN status in either direction. Provenance for trees should be labeled "global IUCN (Belize-filtered)," not "national," when merging with the fauna lists.
- Comparing the 2020 and 2025 bird lists: Collared Plover dropped from CR to EN; several terns (Roseate Tern, Brown Noddy, Least Tern, Sandwich Tern) dropped out of CR entirely and now sit at VU or off the CR table; Red Crossbill remained CR in both. **2025 should be treated as authoritative on conflict** (same author/methodology, more recent).
- Roseate Tern (Sterna dougallii) appears in the 2020 CR list but does not appear in the 2025 national list at all - flagged as "dropped between assessments," not auto-included at its 2020 category, since it's unclear whether this reflects a real change or an omission.
- Furrowed Wood Turtle (Rhinoclemmys areolata) appears in both the VU list and the Watch List within the 2025 source document itself - an internal inconsistency in the source, not introduced here. Resolved to the more severe status (VU).
- "Central American Worm Salamander" (Oedipina elongata) is filed under the Reptiles heading in the 2025 Watch List, despite being an amphibian - a data-entry quirk in the source document, corrected here (class = Amphibia).
- "Harpalyce rupicola / torresii" in the original tree workshop report is an uncertain identification between two species; resolved here to *Harpalyce torresii* per the compiled CSV, flagged for taxonomic QA.
