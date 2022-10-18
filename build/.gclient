solutions = [
  {
    "name": "src",
    "url": "https://chromium.googlesource.com/chromium/src.git",
    "managed": False,
    "custom_deps": {
      "src/chrome/test/data/perf/canvas_bench": None,
      "src/chrome/test/data/perf/frame_rate/content": None,
      "src/chrome/test/data/xr/webvr_info": None,
      "src/components/zucchini": None,
      "src/third_party/android_rust_toolchain/toolchain": None,
      "src/third_party/checkstyle": None,
      "src/third_party/jdk": None,
      "src/third_party/jdk/extras": None,
      "src/tools/perf/page_sets/maps_perf_test": None,
    },
    "custom_vars": {
      "checkout_configuration": "small",
      "checkout_js_coverage_modules": False,
      "checkout_linux": True,
      "checkout_nacl": False,
      "checkout_pgo_profiles": True,
      "checkout_x64": False,
      "checkout_x86": False,
      "generate_location_tags": False,
    },
  },
]
target_os = ["linux"]
