# Purpose and scope

This document describes the business domain behind the Peat Rewetting Planning system using Domain-Driven Design (DDD). It explains the language used by the people who plan peatland rewetting, splits the problem into bounded contexts, and names the aggregates, rules and events that the database enforces.

It is written for three readers:

- **Presenters and project managers** who need to explain what the system models and why.
- **Engineers** who extend the database, the OGC API or a future web application.
- **Domain experts** who want to check that the model matches how planning and review actually work.

The implementation details (tables, columns, deployment) are covered in the companion documents: *Entity Relationship Diagram*, *Database Schema* and *System Architecture Document*.

# Domain overview

Indonesia manages its peatlands in **Peat Hydrological Units** (Kesatuan Hidrologis Gambut, KHG). A KHG is a peat dome bounded by rivers, and it behaves as one hydrological system. Drained peat dries out and burns, so the national programme rewets it by:

1. **Blocking canals** with canal blocks (sekat kanal) placed where a canal crosses a contour line, so that each block holds back a fixed drop in water level.
2. **Pumping water** from rivers into the canal network during the dry season.
3. **Monitoring** groundwater level (TMAT), deep wells and fire hotspots.

Planning happens **per KHG**. An analyst prepares a plan in QGIS or in the web application, a reviewer from the ministry checks it against automatic validation rules, and an approved plan is printed as an A0 poster for field teams. Every change must be traceable to a person, a tool and a plan version.

The system currently holds 866 KHG, of which 345 contain the 2,004 target villages for 2026. The user interface calls this programme "337 KHG".

# Ubiquitous language

The team uses Indonesian terms. The database keeps those names so that analysts recognise them; this table is the shared dictionary.

| Term (database) | English term | Meaning | Stored in |
|---|---|---|---|
| KHG | Peat Hydrological Unit | Planning unit. Every plan, review and poster belongs to one KHG. | `ref.khg` |
| Sekat kanal | Canal block | Small dam in a canal. *Rencana* means planned, *existing* means built. | `peta.sekat` |
| Kanal | Canal | Drainage channel; primer, sekunder or tersier (primary, secondary, tertiary). | `peta.kanal` |
| Kanal aktif | Active canal | Canal that still carries water, confirmed by field survey. | `peta.kanal.status` |
| Pompa | Pump | Planned or installed pump that moves river water into canals. | `peta.pompa` |
| Pintu air | Water gate | Gate structure that controls canal flow. | `peta.pintu_air` |
| Sungai | River | Water source for pumps. | `peta.sungai` |
| Sumur bor | Deep well | Well used for fire fighting and rewetting, with daily discharge. | `peta.sumur_bor` |
| Logger AP-TMAT | Groundwater logger | Sensor that records groundwater depth; alert above 0.4 m. | `peta.logger_tmat` |
| Hotspot | Fire hotspot | Satellite fire detection (MODIS, VIIRS). | `peta.hotspot` |
| Areal terbakar | Burned area | Burn scar polygon with the list of years it burned. | `peta.areal_terbakar` |
| Ketebalan gambut | Peat thickness | Depth class of the peat layer. Peat at least 3 m deep has a protection function. | `peta.ketebalan_gambut` |
| Konsesi | Concession | Plantation or forestry permit area owned by a company. | `peta.konsesi` |
| Unit analisis | Analysis unit | Polygon from overlaying KHG, village, concession, forest status, peat and burn history. | `analisis.unit_*` |
| Versi KHG | Plan version | Numbered snapshot of the plan for one KHG (v1, v2 and so on). | `alur.khg_versi` |
| Status alur | Workflow status | Draft, review, revisi (revision requested), approved, printed. | `ref.status_alur` |
| Perubahan | Change record | Audit entry for one create, update or delete. | `alur.perubahan` |
| Validasi otomatis | Automatic validation | Rule check run before review. | `alur.validasi_khg()` |
| Saran lokasi | Location suggestion | Ranked candidate sites for a new pump. | `peta.saran_lokasi_pompa()` |
| Ekspor poster | Poster export | Job that renders a plan as an A0 to A3 map. | `alur.ekspor_poster` |
| Via | Channel | Tool that made a change: qgis, web, api, sync or import. | meta column `updated_via` |

# Subdomains

| Type | Subdomain | Why it has this type |
|---|---|---|
| Core | **Rewetting infrastructure planning** | This is where the programme creates value: where to put blocks and pumps. |
| Core | **Plan review and versioning** | Accountability to the ministry depends on traceable, approved plans. |
| Supporting | Fire and peat risk | Inputs that prioritise KHG and score pump locations. |
| Supporting | Field monitoring | Feedback from the ground (groundwater, wells) after construction. |
| Supporting | Spatial analysis | Pre-computed overlays that give every location its context. |
| Supporting | Publication | Posters and the OGC API that share results with other teams. |
| Generic | Reference data | Administrative regions, companies and code lists. |
| Generic | Identity and access | Database roles and HTTP Basic authentication. |

# Bounded contexts

Each bounded context owns a clear part of the model and speaks its own slice of the ubiquitous language. In this system a context maps to a group of tables inside one PostgreSQL schema.

| Bounded context | Responsibility | Main objects | Schema |
|---|---|---|---|
| **Reference** | Regions, KHG boundaries, companies and code lists that every other context uses. | Province, Regency, District, Village, KHG, Company, lookups | `ref` |
| **Infrastructure Planning** | Canals, canal blocks, pumps, water gates and rivers of a KHG plan. | Canal, Canal Block, Pump, Water Gate, River | `peta` |
| **Risk** | Hotspots, burned areas, peat thickness and concessions. | Hotspot, Burned Area, Peat Thickness, Concession | `peta` |
| **Field Monitoring** | Groundwater loggers, deep wells and fire posts with their time series. | Logger, Reading, Deep Well, Discharge, Fire Post | `peta` |
| **Spatial Analysis** | National and target-area analysis units and contour lines. Read only. | Analysis Unit, Contour | `analisis` |
| **Plan Review** | Versions, change records, comments, validation, poster exports. | Plan Version, Change Record, Comment, Poster Export | `alur` |
| **Publication** | Stable public read model and OGC API. | Public views, OGC collections and processes | `api` |

## Context map

```{.mermaid}
flowchart TB
  REF[Reference]
  ANA[Spatial Analysis]
  RISK[Risk]
  MON[Field Monitoring]
  PLAN[Infrastructure Planning]
  REV[Plan Review]
  PUB[Publication]
  REF -- shared kernel --> ANA
  REF -- shared kernel --> RISK
  REF -- shared kernel --> PLAN
  REF -- shared kernel --> MON
  ANA -- customer supplier --> RISK
  RISK -- customer supplier --> PLAN
  PLAN -- domain events --> REV
  MON -- domain events --> REV
  PLAN -- open host service --> PUB
  RISK -- open host service --> PUB
  REV -- open host service --> PUB
```
<p class="figure-note">Figure 1. Context map between the internal bounded contexts.</p>

External sources enter through an anti-corruption layer (ACL): the ETL scripts in `scripts/` and `db/04` to `db/08`.

| External source | Enters context | What the ACL translates |
|---|---|---|
| BRGM PPEG canal blocks and hydrological infrastructure | Infrastructure Planning | Removes duplicates, fixes a wrong contour field, unifies codes, links blocks to canals by location |
| BlueBook PEG 2026 geodatabase | Reference, Spatial Analysis | Normalises names and units, dissolves KHG boundaries, concessions and peat thickness |
| FIRMS and SiPongi hotspot exports | Risk | Merges two file formats, converts local time zones to UTC, unifies confidence levels |
| Burn scar mapping 2015 to 2026 | Risk | Converts twelve year columns into one list of burn years |
| Deep Well system (future) | Field Monitoring | Planned synchronisation keyed by external id |

How to read the relationships:

- **Anti-corruption layer (ACL).** External shapefiles and geodatabases use inconsistent names, mixed units and duplicate rows. The ETL scripts (`scripts/`, `db/04` to `db/08`) translate them into the clean model, so no external format leaks into the core.
- **Shared kernel.** The Reference context (KHG, villages, companies, code lists) is shared by every other context and changes rarely.
- **Customer and supplier.** Spatial Analysis supplies the KHG boundaries, concessions and peat thickness that Risk uses. Risk supplies scores that Planning uses to rank pump locations.
- **Domain events.** Planning and Monitoring do not call Plan Review. Instead, every change emits a change record that Plan Review attaches to the open version.
- **Open host service.** Publication exposes a stable, standards-based interface (OGC API) so that outside teams do not depend on internal tables.

# Aggregates

An aggregate is a cluster of objects that must stay consistent together. Changes go through the aggregate root, and invariants are enforced at that boundary. The table below lists the aggregates and where each invariant is enforced.

| Aggregate (root) | Members | Key invariants | Enforced by |
|---|---|---|---|
| **Plan Version** (`khg_versi`) | Change records, comments, validation snapshot, poster exports | At most one open version (draft, review or revisi) per KHG. Version numbers increase by one. Status follows the allowed transitions. | Partial unique index, `alur.versi_terbuka()`, `alur.ajukan_review()`, `alur.putuskan()` |
| **Canal Block** (`sekat`) | Overlay context (value object), building details (entity) | Code `SK-n` unique within a KHG. Status from the code list. Point geometry in EPSG:4326. KHG derived from location when missing. | Unique index, FK, `isi_meta`, `isi_kode` triggers |
| **Canal** (`kanal`) | None | Code `K-n` unique within a KHG. Length always equals the geodesic length of the geometry. A missing status means "not surveyed". | Unique index, generated column |
| **Pump** (`pompa`) | Suitability scores (value object) | Code `P-n` unique within a KHG. Each score between 0 and 1. Should be within 500 m of a water source and outside concessions. | CHECK constraints, validation function |
| **Deep Well** (`sumur_bor`) | Daily discharge readings | One reading per well per day. External id unique. | Composite primary key, unique constraint |
| **Groundwater Logger** (`logger_tmat`) | Readings | One reading per logger per timestamp. Alert when the latest depth exceeds 0.4 m. | Composite primary key, `peta.v_tmat_alert` |
| **Poster Export** (`ekspor_poster`) | None | Progress from 0 to 100. Status is waiting, rendering, done, failed or cancelled. Finishing marks the approved version as printed. | CHECK constraints, `tandai_dicetak` trigger |

Objects that are **facts**, not aggregates, are imported and never edited by planners: hotspots, burned areas, analysis units and contours. They are treated as immutable reference data from the planner's point of view.

## Entities and value objects

| Kind | Examples | Identity |
|---|---|---|
| Entity | KHG, Canal Block, Canal, Pump, Plan Version, Deep Well | Surrogate `id` (bigint identity) plus a human code such as `SK-24` |
| Value object | Location (point geometry), suitability score set, overlay context of a canal block, burn years (`smallint[]`), peat thickness class | Defined only by its values |
| Immutable record | Change record, hotspot, reading | Append only |

## Plan Version lifecycle

```{.mermaid}
stateDiagram-v2
  [*] --> draft: first edit in a KHG
  draft --> review: ajukan_review()
  revisi --> review: ajukan_review()
  review --> approved: putuskan(approved)
  review --> revisi: putuskan(revisi)
  approved --> printed: poster export done
  approved --> draft_next: any edit
  printed --> draft_next: any edit
  draft_next --> [*]
  note right of draft_next
    A new version n+1 opens as draft.
    The approved version stays frozen.
  end note
```
<p class="figure-note">Figure 2. State machine of a plan version.</p>

# Domain events

The database raises these events through triggers and functions. They are stored as rows, which makes them auditable and easy to replay.

| Event | Raised when | Raised by | Effect |
|---|---|---|---|
| FeatureCreated, FeatureUpdated, FeatureDeleted | A planning feature changes (QGIS, web or API) | `z_audit` trigger (`alur.catat_perubahan`) | Change record with old and new values, user and channel, linked to the open version |
| VersionOpened | The first change after approval, or the first change ever | `alur.versi_terbuka()` | New draft version n+1 |
| VersionSubmitted | Analyst submits for review | `alur.ajukan_review()` | Status review and a frozen validation snapshot |
| VersionApproved, RevisionRequested | Reviewer decides | `alur.putuskan()` | Status approved or revisi, reviewer note |
| PosterExportCompleted | Render job finishes | Update of `ekspor_poster.status` | Triggers VersionPrinted |
| VersionPrinted | Approved version was exported | `tandai_dicetak` trigger | Status printed |
| StatisticsRefreshed | Daily job or manual request | `api.refresh_statistik()` | KHG statistics recomputed |

Unchanged saves (for example QGIS saving a layer with no edits) do **not** raise events. The trigger compares old and new values first.

# Domain services

| Service | Question it answers | Implementation |
|---|---|---|
| Validate plan version | Is this plan ready for review? | `alur.validasi_khg(version, max_distance)`: pumps near water, pumps outside concessions, canals surveyed, pump capacity filled, valid geometry |
| Suggest pump locations | Where should the next pump go? | `peta.saran_lokasi_pompa(khg, max_distance, min_peat, concession_buffer)`: samples active canals and scores distance to river, canal class, peat thickness and burn history |
| Prioritise KHG | Which KHG need attention first? | `api.khg.skor_prioritas`: 40 percent burned share, 30 percent deep peat share, 30 percent recent hotspots |
| Allocate codes | What is the next human-readable code? | `alur.isi_kode()` trigger: `P-n`, `SK-n`, `K-n` per KHG with an advisory lock |
| Locate KHG | Which KHG does a new feature belong to? | `alur.isi_meta()` trigger: spatial lookup when `khg_id` is empty |

# Business rules catalogue

| No | Rule | Type | Where |
|---|---|---|---|
| R1 | Every planning feature belongs to at most one KHG, derived from its location when not given. | Invariant | `isi_meta` trigger |
| R2 | A KHG has at most one open plan version at any time. | Invariant | Partial unique index on `khg_versi` |
| R3 | Approved and printed versions never change; new edits open a new version. | Invariant | `versi_terbuka()` |
| R4 | Every change records who made it, with which tool and when. | Policy | `catat_perubahan()` as SECURITY DEFINER |
| R5 | A pump should be within 500 m of a river or active canal. | Validation (error) | `validasi_khg()` |
| R6 | A pump must not be inside a concession. | Validation (error) | `validasi_khg()` |
| R7 | Every canal must have a survey status before approval. | Validation (error) | `validasi_khg()` |
| R8 | Every pump should have a capacity. | Validation (warning) | `validasi_khg()` |
| R9 | Pump suitability scores lie between 0 and 1. | Invariant | CHECK constraints |
| R10 | Groundwater deeper than 0.4 m below surface raises an alert. | Policy | `peta.v_tmat_alert` |
| R11 | Public users may read everything; only authenticated editors may write. | Policy | Caddy proxy and database roles |
| R12 | Web clients must not overwrite someone else's newer edit. | Policy | Optimistic lock on `rev` |

# Mapping to the implementation

| Context | Tables | OGC API collections and processes |
|---|---|---|
| Reference | `ref.*` | `khg`, `desa` |
| Infrastructure Planning | `peta.kanal`, `sekat`, `sekat_konteks`, `sekat_bangunan`, `pompa`, `pintu_air`, `sungai` | `sekat`, `sekat-edit`, `kanal`, `pompa`, `pintu-air`, `sungai`; process `saran-lokasi-pompa` |
| Risk | `peta.hotspot`, `areal_terbakar`, `ketebalan_gambut`, `konsesi` | `hotspot`, `areal-terbakar`, `ketebalan-gambut`, `konsesi` |
| Field Monitoring | `peta.logger_tmat`, `tmat_bacaan`, `sumur_bor`, `sumur_debit`, `posko_karhutla` | `logger-tmat`, `sumur-bor`, `posko-karhutla` |
| Spatial Analysis | `analisis.*` | `unit-nasional`, `unit-target-2026`, `kontur`, `kontur-lidar` |
| Plan Review | `alur.*` | processes `validasi-khg`, `ajukan-review`, `putuskan-review`, `ringkasan-dashboard` |
| Publication | `api.*` views | all read collections, tiles, `refresh-statistik` |

# Open questions for domain experts

1. **Priority score.** The weights (40, 30 and 30 percent) are provisional. What formula does the directorate use?
2. **Pump suitability.** The weights for water distance, canal class, peat thickness and burn history (35, 25, 20 and 20 percent) are provisional.
3. **KHG codes.** The official codes such as `KHG.14.12` are not in any source dataset. Which decree lists them?
4. **Canal status.** Who confirms whether a canal is active, and how often?
5. **Hotspot source.** Should monthly counts use one satellite source only? The current data mixes MODIS-only months with MODIS plus VIIRS months, which biases monthly trends.
