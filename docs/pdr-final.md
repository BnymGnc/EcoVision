# Final PDR draft

Problem: an individual needs a reliable next action for a waste item, including packaging eligibility and an appropriate return point.

Solution: photograph an item, obtain a material estimate, answer short packaging questions, inspect material-relevant DOA locations and open directions. Education, 200 catalogued quests and separate activity records support retention without treating XP as verified environmental impact.

Architecture: Flutter client, Spring Boot 3 modular monolith, PostgreSQL/Neon, HTTP JSON/multipart APIs and STOMP group chat. Point import uses provider UUIDs, snapshot hashes and data-quality information. Visual AI is separated from deterministic rules and arithmetic.

Validation: see the actual test results in `verification.md`. A proposed campus pilot should measure sorting answers, point-discovery time, correction rate and user-declared returns. No causal waste-reduction baseline has been measured.

Business hypothesis: institutional campaign/participation analytics. Customers, contracts and paid demand are not validated. Delivery requirements and incomplete external checks remain explicit.
