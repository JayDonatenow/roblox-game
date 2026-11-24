#!/usr/bin/env python3
"""Builds MutationLab.rbxlx from src/ so it can be opened in Roblox Studio without Rojo."""
import os, itertools
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ids = itertools.count(1)

def ref():
    return "RBX%032X" % next(ids)

def src(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        text = f.read()
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"

def script(cls, name, path):
    return (f'<Item class="{cls}" referent="{ref()}"><Properties>'
            f'<string name="Name">{escape(name)}</string>'
            f'<ProtectedString name="Source">{src(path)}</ProtectedString>'
            f'</Properties></Item>')

def folder(name, children):
    return (f'<Item class="Folder" referent="{ref()}"><Properties>'
            f'<string name="Name">{escape(name)}</string></Properties>{"".join(children)}</Item>')

def service(cls, children):
    return f'<Item class="{cls}" referent="{ref()}"><Properties></Properties>{"".join(children)}</Item>'

baseplate = (f'<Item class="Part" referent="{ref()}"><Properties>'
    '<string name="Name">Baseplate</string><bool name="Anchored">true</bool>'
    '<Vector3 name="size"><X>512</X><Y>20</Y><Z>512</Z></Vector3>'
    '<CoordinateFrame name="CFrame"><X>0</X><Y>-10</Y><Z>0</Z>'
    '<R00>1</R00><R01>0</R01><R02>0</R02><R10>0</R10><R11>1</R11><R12>0</R12>'
    '<R20>0</R20><R21>0</R21><R22>1</R22></CoordinateFrame>'
    '</Properties></Item>')
spawn = (f'<Item class="SpawnLocation" referent="{ref()}"><Properties>'
    '<string name="Name">SpawnLocation</string><bool name="Anchored">true</bool>'
    '<Vector3 name="size"><X>12</X><Y>1</Y><Z>12</Z></Vector3>'
    '<CoordinateFrame name="CFrame"><X>0</X><Y>0.5</Y><Z>0</Z>'
    '<R00>1</R00><R01>0</R01><R02>0</R02><R10>0</R10><R11>1</R11><R12>0</R12>'
    '<R20>0</R20><R21>0</R21><R22>1</R22></CoordinateFrame>'
    '</Properties></Item>')

shared = folder("Shared", [
    script("ModuleScript", "Config", "src/shared/Config.luau"),
    script("ModuleScript", "Creatures", "src/shared/Creatures.luau"),
    script("ModuleScript", "Fusion", "src/shared/Fusion.luau"),
])
server = folder("Server", [
    script("Script", "Main", "src/server/Main.server.luau"),
    script("ModuleScript", "PlayerData", "src/server/PlayerData.luau"),
    script("ModuleScript", "DiscoveryLog", "src/server/DiscoveryLog.luau"),
])
client = script("LocalScript", "UI", "src/client/UI.client.luau")

items = [
    service("Workspace", [baseplate, spawn]),
    service("ReplicatedStorage", [shared]),
    service("ServerScriptService", [server]),
    service("StarterPlayer", [service("StarterPlayerScripts", [client])]),
]
out = '<roblox version="4">' + "".join(items) + "</roblox>"
path = os.path.join(ROOT, "MutationLab.rbxlx")
with open(path, "w", encoding="utf-8") as f:
    f.write(out)
print("wrote", path, len(out), "bytes")
