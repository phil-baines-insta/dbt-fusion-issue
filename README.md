- sample packages.yml entry
```yml
packages:
  - local: "{{ env_var('CHILD_DBT_DIR') }}"
```

From root
```bash
source .env
```

Result with parsing between core vs fusion
```bash
# dbt-core
parent % dbt parse
22:22:56  Running with dbt=1.8.8
22:22:56  Registered adapter: snowflake=1.8.4
22:22:57  Performance info: ...

# dbt-fusion
# deps
parent % dbtf deps
dbt-fusion 2.0.0-preview.154
   Loading ../profiles.yml
  Finished [  0.21s] resolving packages from packages.yml (1 items)
 Installed child
 Installed 1 package

Finished 'deps' with 2 warnings for target 'snowflake' [901ms]

# parss
parent % dbtf parse
dbt-fusion 2.0.0-preview.154
   Loading ../profiles.yml
  Finished [  0.15s] resolving packages from packages.yml (1 items)

==================================================================================================== Errors and Warnings ====================================================================================================
warning: dbt1005: Package dependency '{{ env_var('CHILD_DBT_DIR') }}' not found in package-lock.yml. Skipping. Run 'fs deps --upgrade' with a packages.yml to resolve all dependencies.

===================================================================================================== Execution Summary =====================================================================================================
```