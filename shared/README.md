# Shared Design Assets

Use these directories for assets shared by multiple teams:

- `rtl/`: common packages, interfaces, constants, and reusable RTL
- `tb/`: shared testbench components and protocol monitors
- `scripts/`: common tool setup and lint/simulation helpers
- `cells/`: custom inverter, scan-DFF, Liberty, LEF, and characterization data
- `constraints/`: shared technology and clocking constraints
- `reports/`: shared characterization and integration summaries

Do not place team-specific implementation files here without an interface review.