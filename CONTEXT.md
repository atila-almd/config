# blendOS Workstation

This context names the concepts used to build a personal, integrated desktop
environment on blendOS while remaining independent from Omarchy-specific
choices.

## Language

**Workstation Environment**:
The complete personal desktop experience managed by this repository on top of
blendOS, distinct from a standalone distribution or a blendOS fork.
_Avoid_: Distro, Omarchy clone

**Workflow**:
A concrete task the owner expects to complete through the Workstation
Environment. Workflows justify capabilities; parity with another environment
does not.
_Avoid_: Feature checkbox, Omarchy parity

**Capability**:
A user-visible responsibility of the Workstation Environment, such as launching
applications, showing notifications, or running containers. A capability may
be fulfilled by one component or a coordinated set of components.
_Avoid_: Package, app

**Component**:
An upstream application, service, or project-owned helper selected to fulfill
all or part of a Capability.
_Avoid_: Capability, package entry

**Component Contract**:
The repository's explicit mapping from a Capability to its package,
executable, and Integration Point.
_Avoid_: Package list, inventory

**Integration Point**:
The place through which a Component participates in the Workstation
Environment, such as a session service, keybinding, launcher, or XDG default.
_Avoid_: Hook, glue

**Integrated Capability**:
A Capability whose components are installed, reachable, lifecycle-aware, and
consistent with the environment's defaults and interaction model.
_Avoid_: Installed package, enabled feature

**Session Component**:
A Component whose useful lifetime is bounded by the graphical session.
It starts and stops through the shared user-session lifecycle.
_Avoid_: Startup app, background app

**System Definition**:
The declarative blendOS description of system packages, services, and rebuild
commands.
_Avoid_: Installer, package script

**Managed Configuration**:
Version-controlled configuration deployed from this repository into the target
account or system.
_Avoid_: Local state, dotfiles backup

**Local State**:
Machine-specific, runtime, generated, personal, or secret data that must not be
treated as Managed Configuration.
_Avoid_: Config, source file

**Machine Profile**:
A coherent set of hardware-specific packages and services for one supported
target machine or virtual machine.
_Avoid_: Optional package pile, hardware tweak

**Compatibility Shim**:
A small, isolated adaptation that lets a chosen Component work within the
Workstation Environment without redefining the component's broader behavior.
_Avoid_: Fork, permanent patch set

**Project Fork**:
A separately maintained copy of an upstream Component adopted only when a
required change cannot be achieved through configuration, composition, or a
Compatibility Shim.
_Avoid_: Customization, vendored tool

**Omarchy Reference**:
Omarchy as a source of integration ideas and, when justified, individual
components. It is neither the Workstation Environment's specification nor its
default dependency boundary.
_Avoid_: Upstream distro, required base
