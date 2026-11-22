"""Checks value_sites.lua and the building_placement / stances sections against real executables.

Runs Rebalancer's own Lua (init.lua, value_sites.lua) in Lua 5.4 through lupa, with a small
stand-in for the framework's `core` that serves the executable's bytes as the game's memory.
No game is started and no file is written.

    pip install lupa
    python tests/test_value_sites.py "<game folder>"

The folder needs "Stronghold Crusader.exe" and/or "Stronghold_Crusader_Extreme.exe" (1.41).
"""
import os
import struct
import sys
import unittest

from lupa import lua54

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = sys.argv.pop(1) if len(sys.argv) > 1 else os.environ.get('SHC_GAME_DIR', '')
EXES = {'Crusader': 'Stronghold Crusader.exe', 'Extreme': 'Stronghold_Crusader_Extreme.exe'}


class Image:
    """The executable's sections at their virtual addresses."""

    def __init__(self, path):
        with open(path, 'rb') as f:
            data = f.read()
        nt = struct.unpack_from('<I', data, 0x3C)[0]
        count = struct.unpack_from('<H', data, nt + 6)[0]
        opt_size = struct.unpack_from('<H', data, nt + 20)[0]
        self.base = struct.unpack_from('<I', data, nt + 24 + 28)[0]
        size = struct.unpack_from('<I', data, nt + 24 + 56)[0]
        self.mem = bytearray(size)
        headers = struct.unpack_from('<I', data, nt + 24 + 60)[0]
        self.mem[0:headers] = data[0:headers]
        section = nt + 24 + opt_size
        for _ in range(count):
            vsize, va, raw_size, raw_ptr = struct.unpack_from('<IIII', data, section + 8)
            chunk = data[raw_ptr:raw_ptr + min(raw_size, max(vsize, raw_size))]
            self.mem[va:va + len(chunk)] = chunk
            section += 40
        self.original = bytes(self.mem)
        self.writes = []
        self.scans = []

    def off(self, address):
        offset = address - self.base
        if not 0 <= offset < len(self.mem):
            raise IndexError(hex(address))
        return offset

    def read(self, address, count):
        offset = self.off(address)
        return bytes(self.mem[offset:offset + count])

    def write(self, address, values):
        offset = self.off(address)
        for index, value in enumerate(values):
            self.mem[offset + index] = value & 0xFF
        self.writes.append((address, bytes(v & 0xFF for v in values)))

    def scan(self, signature, low, high):
        self.scans.append(signature)
        pattern = [None if t in ('?', '??') else int(t, 16) for t in signature.split()]
        low = max(low, self.base)
        high = min(high, self.base + len(self.mem))
        # longest fixed run as the anchor
        best, start = (0, 0), None
        for i, v in enumerate(pattern + [None]):
            if v is not None and start is None:
                start = i
            elif v is None and start is not None:
                if i - start > best[1] - best[0]:
                    best = (start, i)
                start = None
        anchor = bytes(pattern[best[0]:best[1]])
        position = self.mem.find(anchor, self.off(low) + best[0])
        while position != -1:
            begin = position - best[0]
            address = self.base + begin
            if address >= high:
                return None
            if address >= low and all(v is None or self.mem[begin + k] == v for k, v in enumerate(pattern)):
                return address
            position = self.mem.find(anchor, position + 1)
        return None

    def changed(self):
        return [i for i in range(len(self.mem)) if self.mem[i] != self.original[i]]


def runtime(image, extreme, miss=None):
    lua = lua54.LuaRuntime(unpack_returned_tuples=True)
    logs = []
    g = lua.globals()
    g.package.path = ROOT.replace('\\', '/') + '/?.lua;' + g.package.path

    def read_bytes(address, count):
        return lua.table_from(list(image.read(int(address), int(count))))

    def read_int(address):
        return struct.unpack('<i', image.read(int(address), 4))[0]

    def read_short(address):
        return struct.unpack('<h', image.read(int(address), 2))[0]

    def read_byte(address):
        return struct.unpack('<b', image.read(int(address), 1))[0]

    def write_code_bytes(address, values):
        image.write(int(address), [int(values[i + 1]) for i in range(len(values))])

    def scan(signature, low=None, high=None):
        return image.scan(signature, int(low or 0x400000), int(high or 0x7FFFFFFF))

    def log(level, message):
        logs.append((level, message))

    g.py_read_bytes, g.py_read_int, g.py_read_short, g.py_read_byte = read_bytes, read_int, read_short, read_byte
    g.py_write_code_bytes, g.py_scan, g.py_log, g.py_extreme = write_code_bytes, scan, log, extreme
    g.py_miss = miss   # what scanForAOB returns on a miss: nil here, 0 as the framework documents
    lua.execute('''
        ERROR, WARNING, INFO, DEBUG = 1, 2, 3, 4
        log = function(level, message) py_log(level, message) end
        core = {
          readBytes = py_read_bytes, readInteger = py_read_int, readSmallInteger = py_read_short,
          readByte = py_read_byte, writeCodeBytes = py_write_code_bytes,
          scanForAOB = function(signature, low, high)
            local found = py_scan(signature, low, high)
            if found == nil then return py_miss end
            return math.tointeger(found)
          end,
        }
        data = { version = { isExtreme = function() return py_extreme end } }
        function table.find(t, value) for i, v in ipairs(t) do if v == value then return i end end end
    ''')
    return lua, logs


def dump_lua(lua, value):
    """A Python dict/number as a Lua table literal."""
    if isinstance(value, dict):
        return '{' + ', '.join('[%r] = %s' % (k, dump_lua(lua, v)) for k, v in value.items()) + '}'
    return repr(value)


class ValueSites:
    edition = None
    image = None
    miss = None

    def setUp(self):
        self.image = Image(os.path.join(GAME, EXES[self.edition]))
        self.lua, self.logs = runtime(self.image, self.edition == 'Extreme', self.miss)
        self.rebalancer = self.lua.eval('(require("init"))')
        self.image.scans.clear()
        self.sites = self.lua.eval('(require("value_sites"))')

    def apply(self, config):
        self.lua.execute('cfg = ' + dump_lua(self.lua, config))
        self.rebalancer.apply_rebalance(self.lua.globals().cfg)

    def errors(self):
        return [m for level, m in self.logs if level == 1]

    def address(self, site, value):
        """Where the test itself finds the value (independent of the module's resolver)."""
        spec = self.sites._sites[site]
        found = self.image.scan(spec.signature, 0x401000, 0x59E000)
        return found + spec['values'][value]['value'], spec['values'][value]['width']

    def value_at(self, site, value):
        address, width = self.address(site, value)
        return int.from_bytes(self.image.read(address, width), 'little', signed=True), address, width

    # --- keys absent: nothing is scanned or written -------------------------------------------
    def test_absent_keys_change_nothing(self):
        self.apply({})
        self.apply({'building_placement': {}, 'stances': {}})
        self.assertEqual(self.image.writes, [])
        self.assertEqual(self.image.scans, [])
        self.assertEqual([m for _, m in self.logs if 'rebalancer' in m], [])

    # --- every site: found once, game default in place, every write lands on the value only ----
    def test_every_value_written_alone(self):
        cases = [
            ({'building_placement': {'castle_build_range': {'map_160': 70}}}, 'castle_build_range', 'map_160', 70),
            ({'building_placement': {'castle_build_range': {'map_200': 71}}}, 'castle_build_range', 'map_200', 71),
            ({'building_placement': {'castle_build_range': {'map_300': 72}}}, 'castle_build_range', 'map_300', 72),
            ({'building_placement': {'castle_build_range': {'map_400': 73}}}, 'castle_build_range', 'map_400', 73),
            ({'building_placement': {'enemy_unit_radius': {'storage': 15}}}, 'storage_enemy_radius', 'radius', 15),
            ({'building_placement': {'enemy_unit_radius': {'siege_tents': 7}}}, 'siege_tent_enemy_radius', 'radius', 7),
            ({'building_placement': {'enemy_unit_radius': {'ai_walls': 7}}}, 'ai_wall_enemy_radius', 'radius', 7),
            ({'stances': {'max_units_per_enemy': 5}}, 'stance_units_per_enemy', 'count', 5),
            ({'stances': {'aggressive_melee_building_range': 35}}, 'aggressive_melee_building_range', 'range', 35),
            ({'stances': {'aggressive_range': 100}}, 'stance_ranges', 'aggressive', 100),
        ]
        for config, site, value, wanted in cases:
            with self.subTest(site=site, value=value):
                self.setUp()
                before, address, width = self.value_at(site, value)
                self.assertEqual(before, self.sites.defaults(site, value))
                self.apply(config)
                self.assertEqual(self.errors(), [])
                after, _, _ = self.value_at(site, value)
                self.assertEqual(after, wanted)
                changed = self.image.changed()
                self.assertTrue(changed and all(address - self.image.base <= c < address - self.image.base + width
                                                for c in changed), changed)

    def test_defensive_range_moves_its_stance_check(self):
        self.apply({'stances': {'defensive_range': 110}})
        self.assertEqual(self.errors(), [])
        self.assertEqual(self.value_at('stance_ranges', 'defensive')[0], 110)
        self.assertEqual(self.value_at('defensive_stance_check', 'defensive')[0], 110)
        self.assertEqual(self.value_at('stance_ranges', 'aggressive')[0], 200)
        self.assertEqual(len(self.image.changed()), 2)   # one byte of the mov, one of the cmp

    def test_every_key_at_once(self):
        self.apply({
            'building_placement': {'castle_build_range': {'map_160': 70, 'map_200': 70, 'map_300': 70, 'map_400': 80},
                                   'enemy_unit_radius': {'storage': 15, 'siege_tents': 7, 'ai_walls': 7}},
            'stances': {'defensive_range': 80, 'aggressive_range': 100, 'aggressive_melee_building_range': 35,
                        'max_units_per_enemy': 5},
        })
        self.assertEqual(self.errors(), [])
        want = [('castle_build_range', 'map_160', 70), ('castle_build_range', 'map_200', 70),
                ('castle_build_range', 'map_300', 70), ('castle_build_range', 'map_400', 80),
                ('storage_enemy_radius', 'radius', 15), ('siege_tent_enemy_radius', 'radius', 7),
                ('ai_wall_enemy_radius', 'radius', 7), ('stance_ranges', 'defensive', 80),
                ('defensive_stance_check', 'defensive', 80), ('stance_ranges', 'aggressive', 100),
                ('aggressive_melee_building_range', 'range', 35), ('stance_units_per_enemy', 'count', 5)]
        self.assertEqual([self.value_at(s, v)[0] for s, v, _ in want], [w for _, _, w in want])
        infos = [m for level, m in self.logs if level == 3 and m.startswith('[rebalancer]')]
        self.assertEqual(len(infos), 12, infos)

    def test_tester_file(self):
        # the in-game acceptance file: 160x160 build range and storage distance
        self.apply({'building_placement': {'castle_build_range': {'map_160': 70},
                                           'enemy_unit_radius': {'storage': 15}}})
        self.assertEqual(self.errors(), [])
        self.assertEqual(self.value_at('castle_build_range', 'map_160')[0], 70)
        self.assertEqual(self.value_at('castle_build_range', 'map_200')[0], 50)
        self.assertEqual(self.value_at('storage_enemy_radius', 'radius')[0], 15)
        self.assertEqual(self.value_at('siege_tent_enemy_radius', 'radius')[0], 3)
        self.assertEqual(len(self.image.changed()), 2)

    # --- refusals: nothing written, a clear error -------------------------------------------
    def assert_refused(self, config, text):
        self.apply(config)
        self.assertEqual(self.image.changed(), [])
        self.assertTrue(any(text in m for m in self.errors()), self.errors())

    def test_out_of_range(self):
        self.assert_refused({'building_placement': {'enemy_unit_radius': {'storage': 200}}}, 'from 0 to 127')
        self.setUp()
        self.assert_refused({'stances': {'defensive_range': 128}}, 'from 1 to 127')
        self.setUp()
        self.assert_refused({'stances': {'max_units_per_enemy': 1}}, 'from 2 to 1000')
        self.setUp()
        self.assert_refused({'building_placement': {'castle_build_range': {'map_160': 4.5}}}, 'whole number')

    def test_equal_stance_ranges(self):
        self.assert_refused({'stances': {'aggressive_range': 40}}, 'must differ')

    def test_value_changed_by_another_module(self):
        address, width = self.address('storage_enemy_radius', 'radius')
        self.image.mem[address - self.image.base] = 9
        self.image.original = bytes(self.image.mem)
        self.assert_refused({'building_placement': {'enemy_unit_radius': {'storage': 15}}}, 'holds 9')

    def test_ambiguous_signature(self):
        spec = self.sites._sites['aggressive_melee_building_range']
        found = self.image.scan(spec.signature, 0x401000, 0x59E000)
        length = len(spec.signature.split())
        copy = self.image.read(found, length)
        spot = 0x59E000 - 0x100 - self.image.base   # code section padding at its end
        self.image.mem[spot:spot + length] = copy
        self.image.original = bytes(self.image.mem)
        self.assert_refused({'stances': {'aggressive_melee_building_range': 35}}, 'more than once')

    def test_missing_signature(self):
        address, _ = self.address('castle_build_range', 'map_160')
        self.image.mem[address - 1 - self.image.base] = 0x90   # the mov eax opcode
        self.image.original = bytes(self.image.mem)
        self.assert_refused({'building_placement': {'castle_build_range': {'map_160': 70}}}, 'not found')

    def test_stance_group_is_all_or_nothing(self):
        address, _ = self.address('defensive_stance_check', 'defensive')
        self.image.mem[address - 1 - self.image.base] = 0xFE   # cmp ebp -> another register
        self.image.original = bytes(self.image.mem)
        self.assert_refused({'stances': {'defensive_range': 110, 'aggressive_range': 80}}, 'defensive_stance_check')

    def test_unexpected_headers(self):
        self.image.mem[0] = 0   # "MZ" gone: the image base cannot be confirmed
        self.image.original = bytes(self.image.mem)
        self.assert_refused({'stances': {'max_units_per_enemy': 5}}, 'headers at 0x400000')
        self.assertEqual(self.image.scans, [])

    def corrupt_call(self, site):
        spec = self.sites._sites[site]
        found = self.image.scan(spec.signature, 0x401000, 0x59E000)
        call = found + spec.calls.at
        rel = struct.unpack('<i', self.image.read(call + 1, 4))[0]
        self.image.mem[call + 1 - self.image.base:call + 5 - self.image.base] = struct.pack('<i', rel + 16)
        self.image.original = bytes(self.image.mem)

    def test_radius_site_must_call_the_enemy_check(self):
        self.corrupt_call('ai_wall_enemy_radius')
        self.assert_refused({'building_placement': {'enemy_unit_radius': {'ai_walls': 7}}},
                            'does not reach enemy_near_check')

    def test_melee_site_must_call_the_building_search(self):
        self.corrupt_call('aggressive_melee_building_range')
        self.assert_refused({'stances': {'aggressive_melee_building_range': 35}}, 'does not reach building_search')

    def test_radius_settings_stand_alone(self):
        # another module changed the AI wall code: storage and siege tents still apply
        address, _ = self.address('ai_wall_enemy_radius', 'radius')
        self.image.mem[address - 12 - self.image.base] = 0x90   # first byte of that signature
        self.image.original = bytes(self.image.mem)
        self.apply({'building_placement': {'enemy_unit_radius': {'storage': 15, 'siege_tents': 7, 'ai_walls': 7}}})
        self.assertEqual(self.value_at('storage_enemy_radius', 'radius')[0], 15)
        self.assertEqual(self.value_at('siege_tent_enemy_radius', 'radius')[0], 7)
        self.assertEqual(len(self.errors()), 1)
        self.assertIn('ai_walls not applied', self.errors()[0])

    def test_ucp2_legacy_ai_rebuild_either_order(self):
        # UCP2 Legacy's ai_rebuild finds this signature and writes 0x01 at its start
        legacy = ('0C 0F 8C 93 00 00 00 A9 00 04 00 00 0F 85 88 00 00 00 85 C9 0F 85 80 00 00 00 '
                  'A8 14 75 7C A9 81')
        found = self.image.scan(legacy, 0x401000, 0x59E000)
        self.assertIsNotNone(found)
        # Rebalancer after Legacy
        self.image.mem[found - self.image.base] = 0x01
        self.apply({'building_placement': {'enemy_unit_radius': {'ai_walls': 7}}})
        self.assertEqual(self.errors(), [])
        self.assertEqual(self.value_at('ai_wall_enemy_radius', 'radius')[0], 7)
        # Legacy after Rebalancer: its signature still matches once on the changed code
        self.setUp()
        self.apply({'building_placement': {'enemy_unit_radius': {'ai_walls': 7}}})
        self.assertEqual(self.image.scan(legacy, 0x401000, 0x59E000), found)
        self.assertIsNone(self.image.scan(legacy, found + 1, 0x59E000))

    def test_section_must_be_an_object(self):
        self.assert_refused({'building_placement': 5}, 'must be an object')
        self.setUp()
        self.assert_refused({'building_placement': {'castle_build_range': 70}}, 'must be an object')

    def test_unknown_key_warns(self):
        self.apply({'stances': {'max_units_per_enemy': 5, 'max_unit_per_enemy': 6}})
        self.assertEqual(self.errors(), [])
        self.assertEqual(self.value_at('stance_units_per_enemy', 'count')[0], 5)
        warnings = [m for level, m in self.logs if level == 2]
        self.assertTrue(any("unknown key 'max_unit_per_enemy'" in m for m in warnings), warnings)


class ZeroOnMiss:
    """The framework documents 0 (not nil) for a missing signature."""
    miss = 0

    def test_missing_signature_zero(self):
        ValueSites.test_missing_signature(self)

    def test_every_key_at_once_zero(self):
        ValueSites.test_every_key_at_once(self)

def load_tests(loader, tests, pattern):
    suite = unittest.TestSuite()
    for edition, exe in EXES.items():
        if os.path.isfile(os.path.join(GAME, exe)):
            case = type('ValueSites' + edition, (ValueSites, unittest.TestCase), {'edition': edition})
            suite.addTests(loader.loadTestsFromTestCase(case))
            zero = type('ZeroOnMiss' + edition, (ZeroOnMiss, ValueSites, unittest.TestCase), {'edition': edition})
            suite.addTest(zero('test_missing_signature_zero'))
            suite.addTest(zero('test_every_key_at_once_zero'))
        else:
            print('skipped, not found: ' + os.path.join(GAME, exe))
    return suite


if __name__ == '__main__':
    unittest.main(verbosity=2)
