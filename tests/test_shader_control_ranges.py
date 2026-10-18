"""User-visible Shaderfilter parameter contracts; no OBS user profile required."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "data/examples"


def numeric_control(path, name):
    text = (ROOT / path).read_text(errors="replace")
    match = re.search(
        r"uniform\s+(?:float|int)\s+" + re.escape(name) +
        r"\s*<(?P<annotations>.*?)>\s*=\s*(?P<default>-?\d+(?:\.\d+)?)\s*;",
        text, re.S)
    if not match:
        raise AssertionError(f"missing scalar control {path}:{name}")
    body = match.group("annotations")
    def annotation(key):
        found = re.search(r"\b(?:float|int)\s+" + key +
                          r"\s*=\s*(-?\d+(?:\.\d+)?)\s*;", body)
        return float(found.group(1)) if found else None
    choices = {int(value) for value in re.findall(
        r"\bint\s+option_\d+_value\s*=\s*(-?\d+)\s*;", body)}
    return {
        "default": float(match.group("default")),
        "min": annotation("minimum"),
        "max": annotation("maximum"),
        "step": annotation("step"),
        "options": choices,
        "type": re.search(r"widget_type\s*=\s*\"([^\"]+)\"", body).group(1),
    }


class InstalledShaderControlContracts(unittest.TestCase):
    def test_previously_unreachable_defaults_are_usable(self):
        for path, name in [
            ("emboss_color.shader", "ampFactor"),
            ("fire-3.effect", "Flame_Tongue_Size"),
            ("smart_denoise.shader", "uSigma"),
        ]:
            with self.subTest(path=path, control=name):
                c = numeric_control(path, name)
                self.assertLessEqual(c["min"], c["default"])
                self.assertLessEqual(c["default"], c["max"])

    def test_displacement_default_is_a_selectable_curve(self):
        for path in ("displacement_map_advanced.shader",
                     "displacement_map_advanced_invert.shader"):
            with self.subTest(path=path):
                c = numeric_control(path, "displacement_curve")
                self.assertEqual(c["type"], "select")
                self.assertIn(int(c["default"]), c["options"])
                self.assertEqual(c["options"], {1, 2, 3})

    def test_noisemaker_discrete_controls_expose_all_valid_states(self):
        specs = {
            "nm_edge.shader": {
                "kernel": (0, 2, 1),  # Fine/Bold/Contour
                "size": (-1, 1, 1),  # Legacy radius mapping 0/1/2
                "blend": (0, 8, 1),  # Nine blend modes
                "invert": (0, 1, 1),
                "channel": (0, 1, 1),
                "contourSide": (0, 1, 1),
            },
            "nm_sine.shader": {"colorMode": (0, 1, 1)},
            "nm_glowingEdge.shader": {"sobelMetric": (0, 3, 1)},
        }
        for filename, controls in specs.items():
            for name, expected in controls.items():
                path = "myrqyry/noisemaker-ports/" + filename
                with self.subTest(path=path, control=name):
                    c = numeric_control(path, name)
                    self.assertEqual((c["min"], c["max"], c["step"]), expected)
                    self.assertGreaterEqual(c["default"], c["min"])
                    self.assertLessEqual(c["default"], c["max"])


if __name__ == "__main__":
    unittest.main()
