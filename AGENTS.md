# Guidelines for coding assistants

- Script entrypoint is `provision.sh`
- These scripts run both on real hardware and in containerized environments to configure the various prerequisite services and dependencies for the MagAO-X instrument software (github.com/magao-x/MagAOX)
- The Dockerfile defines targets `build`, `cli`, and `gui`.
    - The `build` target has all dependencies, but no MagAO-X software. 
    - The `cli` target builds a minimal set of MagAO-X CLI tools.
    - The `gui` target also builds the Qt-based GUIs.
- The conda environment created by provisioning is active by default in shells (loaded by `/etc/profile.d/conda.sh`)
- Many scripts are only used conditionally based on the value of $MAGAOX_ROLE
    - There are two special roles: `workstation` which builds minimal apps and all GUIs, and `headless` which omits the GUI build.
    - These roles are used to make the `build`/`cli` and `gui` Dockerfile targets.
