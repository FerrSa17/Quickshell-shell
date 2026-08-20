#!/usr/bin/env python3
"""Pair and connect a BlueZ device, answering PIN/passkey from --pin."""
from __future__ import annotations

import argparse
import sys
import traceback

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

AGENT_PATH = "/quickshell/btagent"
AGENT_IFACE = "org.bluez.Agent1"
TIMEOUT_MS = 45000


class Agent(dbus.service.Object):
    def __init__(self, bus: dbus.Bus, pin: str) -> None:
        super().__init__(bus, AGENT_PATH)
        self.pin = pin or ""

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="s")
    def RequestPinCode(self, _device: str) -> str:
        return self.pin or "0000"

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="u")
    def RequestPasskey(self, _device: str) -> dbus.UInt32:
        try:
            return dbus.UInt32(int(self.pin))
        except ValueError:
            return dbus.UInt32(0)

    @dbus.service.method(AGENT_IFACE, in_signature="ou", out_signature="")
    def RequestConfirmation(self, _device: str, _passkey: int) -> None:
        return

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def DisplayPinCode(self, _device: str, _pincode: str) -> None:
        return

    @dbus.service.method(AGENT_IFACE, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, _device: str, _passkey: int, _entered: int) -> None:
        return

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="")
    def RequestAuthorization(self, _device: str) -> None:
        return

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def AuthorizeService(self, _device: str, _uuid: str) -> None:
        return

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Cancel(self) -> None:
        return

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Release(self) -> None:
        return


def fail(msg: str, code: int = 1) -> None:
    sys.stderr.write(msg.rstrip() + "\n")
    raise SystemExit(code)


def device_path(bus: dbus.Bus, address: str) -> tuple[str, dict]:
    want = address.upper()
    obj = bus.get_object("org.bluez", "/")
    mgr = dbus.Interface(obj, "org.freedesktop.DBus.ObjectManager")
    for path, ifaces in mgr.GetManagedObjects().items():
        props = ifaces.get("org.bluez.Device1")
        if not props:
            continue
        if str(props.get("Address", "")).upper() == want:
            return str(path), dict(props)
    fail("Device not found. Make sure it is in range and visible.")
    raise AssertionError


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--address", required=True)
    parser.add_argument("--pin", default="")
    args = parser.parse_args()
    address = str(args.address).strip()
    if not address:
        fail("Missing device address")

    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    loop = GLib.MainLoop()
    result = {"ok": False, "error": "Timed out"}

    try:
        adapter_ok = False
        obj = bus.get_object("org.bluez", "/")
        mgr = dbus.Interface(obj, "org.freedesktop.DBus.ObjectManager")
        for _path, ifaces in mgr.GetManagedObjects().items():
            if "org.bluez.Adapter1" in ifaces:
                adapter_ok = True
                break
        if not adapter_ok:
            fail("No Bluetooth adapter")

        path, props = device_path(bus, address)
        if bool(props.get("Connected")):
            sys.exit(0)

        agent = Agent(bus, str(args.pin or ""))
        manager = dbus.Interface(
            bus.get_object("org.bluez", "/org/bluez"),
            "org.bluez.AgentManager1",
        )
        try:
            manager.RegisterAgent(AGENT_PATH, "KeyboardDisplay")
        except dbus.exceptions.DBusException:
            try:
                manager.UnregisterAgent(AGENT_PATH)
            except dbus.exceptions.DBusException:
                pass
            manager.RegisterAgent(AGENT_PATH, "KeyboardDisplay")
        manager.RequestDefaultAgent(AGENT_PATH)

        dev_obj = bus.get_object("org.bluez", path)
        dev = dbus.Interface(dev_obj, "org.bluez.Device1")
        props_iface = dbus.Interface(dev_obj, "org.freedesktop.DBus.Properties")

        def finish_ok() -> None:
            result["ok"] = True
            result["error"] = ""
            loop.quit()

        def finish_err(err: object) -> None:
            result["ok"] = False
            result["error"] = str(err)
            loop.quit()

        def after_pair() -> None:
            connect()

        def pair_err(err: object) -> None:
            name = str(err)
            if "AlreadyExists" in name:
                connect()
                return
            finish_err(err)

        def connect_err(err: object) -> None:
            name = str(err)
            if "AlreadyConnected" in name or "InProgress" in name:
                finish_ok()
                return
            finish_err(err)

        def connect() -> None:
            try:
                props_iface.Set("org.bluez.Device1", "Trusted", dbus.Boolean(True))
            except dbus.exceptions.DBusException:
                pass
            dev.Connect(
                reply_handler=lambda: finish_ok(),
                error_handler=connect_err,
            )

        if bool(props.get("Paired")):
            connect()
        else:
            dev.Pair(
                reply_handler=after_pair,
                error_handler=pair_err,
            )

        def on_timeout() -> bool:
            result["error"] = "Timed out"
            loop.quit()
            return False

        GLib.timeout_add(TIMEOUT_MS, on_timeout)
        loop.run()

        try:
            manager.UnregisterAgent(AGENT_PATH)
        except dbus.exceptions.DBusException:
            pass
        try:
            agent.remove_from_connection()
        except Exception:
            pass
    except SystemExit:
        raise
    except Exception:
        traceback.print_exc()
        fail("Pairing failed")

    if not result["ok"]:
        fail(result["error"] or "Pairing failed")


if __name__ == "__main__":
    main()
