solutions = [
  {
    "name": "src",
    "url": "https://chromium.googlesource.com/chromium/src.git",
    "managed": False,
    "custom_vars": {
      "checkout_arm": False,
      "checkout_arm64": False,
      "checkout_configuration": "small",
      "checkout_js_coverage_modules": False,
      "checkout_linux": True,
      "checkout_mips64": False,
      "checkout_nacl": False,
      "checkout_pgo_profiles": True,
      "checkout_x64": False,
      "checkout_x86": False,
      "generate_location_tags": False,
    },
  },
]
target_os = ["linux"]
