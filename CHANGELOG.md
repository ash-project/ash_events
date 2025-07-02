# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## v0.4.1 (2025-07-02)




### Bug Fixes:

* handle opts templates when replaying change modules by Zach Daniel

* Proper handling of validation modules in replay change wrapper. by Torkild Kjevik

## v0.4.0 (2025-06-25)




### Features:

* add create_timestamp & update_timestamp in events block. by Torkild Kjevik

* Add allowed_change_modules. by Torkild Kjevik

### Bug Fixes:

* add proper handling of embedded resources. by Torkild Kjevik

* make ash_events work seamlessly with policies & other extensions. by Torkild Kjevik

* handle ash_state_machine transitions. by Torkild Kjevik

* verify actor resources used in persist_actor_primary_key. by Torkild Kjevik

## v0.3.0 (2025-06-04)




### Features:

* add only_actions field in events-section.

### Bug Fixes:

* pass context from the parent to the child

## v0.2.0 (2025-05-19)

* Add option for using UUIDv7 as event log primary key
* Add Postgres transactional advisory locks when inserting events


## v0.1.1 (2025-05-08)


### Features:

* Igniter installer


## v0.1.0 (2025-05-06)
### Breaking Changes:

### Features:

* Initial feature set
