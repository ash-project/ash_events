# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## v0.5.0 (2025-09-19)




### Features:

* Properly distinguish between action input and changed attributes when storing events. by Torkild Kjevik

* Add public_fields-DSL in order to set fields in event logs as public. by Torkild Kjevik.

* Add verifiers for most DSL settings. by Torkild Kjevik.

### Bug Fixes:

* Ensure where-clauses in wrapped changes are respected. by Torkild Kjevik

* add replay validation wrapper to preserve validation messages. by Torkild Kjevik

* Ensure occurred_at is identical to create & update timestamps, enable tracking of changed attributes not in action input. by Torkild Kjevik

* Respect update_default values for attributes when running update actions. by Torkild Kjevik

## v0.4.4 (2025-08-21)




### Bug Fixes:

* Ignore params that are not action attributes or arguments when creating event. by Torkild Kjevik

## v0.4.3 (2025-07-17)




### Bug Fixes:

* properly cast all attrs/args before creating event. by Torkild G. Kjevik

* try converting value to existing atom before dumping. by Torkild G. Kjevik

## v0.4.2 (2025-07-02)




### Bug Fixes:

* include usage-rules in the package files by Zach Daniel

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
