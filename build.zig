const std = @import("std");
const orbis = @import("orbis");

const Translator = @import("translate_c").Translator;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const is_orbis_build = target.result.os.tag == .ps4;

    const use_pic = b.option(bool, "pic", "Produce Position Independent Code");

    //
    // dependencies
    //
    const translate_c = b.dependency("translate_c", .{});

    const c_gcn: Translator = .init(translate_c, .{
        .c_source_file = b.path("include/gnm/gcn/gcn.h"),
        .target = target,
        .optimize = optimize,
        .link_libc = false,
    });

    //
    // setup the library itself
    //
    const mod_gnm = b.addModule("gnm", .{
        .root_source_file = b.path("src/gnm.zig"),
        .imports = &.{
            .{ .name = "c_gcn", .module = c_gcn.mod },
        },
        .target = target,
        .optimize = optimize,
        .link_libc = !is_orbis_build,
        .pic = use_pic,
    });

    mod_gnm.addIncludePath(b.path("include"));
    mod_gnm.addIncludePath(b.path("src"));

    mod_gnm.addCSourceFiles(.{
        .files = &C_SOURCES,
        .flags = &C_FLAGS,
    });
    if (is_orbis_build) {
        mod_gnm.addCSourceFiles(.{
            .files = &.{
                "src/driver_orbis.c",
                "src/platform_orbis.c",
            },
            .flags = &C_FLAGS,
        });
        mod_gnm.linkSystemLibrary("kernel", .{});
        mod_gnm.linkSystemLibrary("SceGnmDriver", .{});
    } else {
        mod_gnm.addCSourceFiles(.{
            .files = &.{
                "src/driver_generic.c",
                "src/platform_generic.c",
            },
            .flags = &C_FLAGS,
        });
    }

    //
    // static library for the user, tools and tests
    //
    const lib_gnm = b.addLibrary(.{
        .linkage = .static,
        .name = "gnm",
        .root_module = mod_gnm,
    });
    b.installArtifact(lib_gnm);

    lib_gnm.installHeadersDirectory(b.path("include"), "", .{});

    //
    // tools
    //
    const exe_gnf_conv = addTool(b, "gnf-conv", &C_SOURCES_GNF_CONV, lib_gnm, target, optimize);
    const exe_gnf_info = addTool(b, "gnf-info", &C_SOURCES_GNF_INFO, lib_gnm, target, optimize);
    const exe_gnf_mk = addTool(b, "gnf-mk", &C_SOURCES_GNF_MK, lib_gnm, target, optimize);
    const exe_pm4_dis = addTool(b, "pm4-dis", &C_SOURCES_PM4_DIS, lib_gnm, target, optimize);

    const exe_gcn_dis = b.addExecutable(.{
        .name = "gcn-dis",
        .root_module = b.createModule(.{
            .root_source_file = b.path("cmd/gcn-dis/main.zig"),
            .imports = &.{
                .{ .name = "gnm", .module = mod_gnm },
            },
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    const exe_psb_dis = b.addExecutable(.{
        .name = "psb-dis",
        .root_module = b.createModule(.{
            .root_source_file = b.path("cmd/psb-dis/main.zig"),
            .imports = &.{
                .{ .name = "gnm", .module = mod_gnm },
            },
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    // don't build tools when targeting the PS4 since they can't be used anyway (for now at least)
    if (!is_orbis_build) {
        b.installArtifact(exe_gcn_dis);
        b.installArtifact(exe_gnf_conv);
        b.installArtifact(exe_gnf_info);
        b.installArtifact(exe_gnf_mk);
        b.installArtifact(exe_pm4_dis);
        b.installArtifact(exe_psb_dis);
    }

    const mod_test_data = b.createModule(.{
        .root_source_file = b.path("test_data/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    //
    // tests
    // TODO: port them to Zig
    //
    const tests_all = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gnm.zig"),
            .imports = &.{
                .{ .name = "gnm", .module = mod_gnm },
                .{ .name = "test_data", .module = mod_test_data },
            },
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    tests_all.root_module.addCSourceFiles(.{
        .files = &.{
            "test/fnf/tests_bmp.c",
            "test/fnf/tests_ktx.c",
            "test/fnf/tests_png.c",
            "test/test.c",
            "test/tests_fetchsh.c",
            "test/tests_gcn.c",
            "test/tests_gnf.c",
            "test/tests_gpuaddr.c",
            "test/tests_pm4.c",
        },
        .flags = &C_FLAGS,
    });
    tests_all.root_module.addIncludePath(b.path("src"));
    tests_all.root_module.addIncludePath(b.path("test"));
    tests_all.root_module.addIncludePath(b.path("include"));

    const run_tests_all = b.addRunArtifact(tests_all);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests_all.step);

    //
    // check stages for ZLS
    //
    const step_check = b.step("check", "Check if the project compiles");

    const check_gnm = b.addLibrary(.{
        .name = "gnm",
        .root_module = mod_gnm,
    });
    const check_gcn_dis = b.addExecutable(.{
        .name = "gcn-dis",
        .root_module = exe_gcn_dis.root_module,
    });
    const check_psb_dis = b.addExecutable(.{
        .name = "psb-dis",
        .root_module = exe_psb_dis.root_module,
    });

    step_check.dependOn(&check_gnm.step);
    step_check.dependOn(&check_gcn_dis.step);
    step_check.dependOn(&check_psb_dis.step);
}

fn addTool(
    b: *std.Build,
    name: []const u8,
    files: []const []const u8,
    lib_gnm: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    exe.root_module.addCSourceFiles(.{
        .files = files,
        .flags = &C_FLAGS,
    });
    exe.root_module.addIncludePath(b.path("src"));
    exe.root_module.linkLibrary(lib_gnm);
    return exe;
}

const C_FLAGS = [_][]const u8{
    "-std=c11",
    "-Wall",
    "-Wextra",
    "-Wpedantic",
    // TODO: fix C code or port parts of it to Zig in order to re-enable UBSAN
    "-fno-sanitize=undefined",
    "-fvisibility=hidden",
};

const C_SOURCES = [_][]const u8{
    "src/fnf/bmp.c",
    "src/fnf/gnf.c",
    "src/fnf/ktex.c",
    "src/fnf/png.c",
    "src/gcn/assembler.c",
    "src/gcn/decoder.c",
    "src/gcn/error.c",
    "src/gcn/format.c",
    "src/gcn/types.c",
    "src/gnf/error.c",
    "src/gnf/validate.c",
    "src/gpuaddr/decompress.c",
    "src/gpuaddr/error.c",
    "src/gpuaddr/surface.c",
    "src/gpuaddr/surfgen.c",
    "src/gpuaddr/tilemodes.c",
    "src/gpuaddr/tiler.c",
    "src/pm4/decoder.c",
    "src/pm4/error.c",
    "src/pm4/format.c",
    "src/pm4/types.c",
    "src/dataformat.c",
    "src/deps.c",
    "src/depthrendertarget.c",
    "src/error.c",
    "src/rendertarget.c",
    "src/shader.c",
    "src/texture.c",
};

const C_SOURCES_GNF_CONV = [_][]const u8{
    "cmd/gnf-conv/main.c",
};
const C_SOURCES_GNF_INFO = [_][]const u8{
    "cmd/gnf-info/main.c",
};
const C_SOURCES_GNF_MK = [_][]const u8{
    "cmd/gnf-mk/main.c",
};
const C_SOURCES_PM4_DIS = [_][]const u8{
    "cmd/pm4-dis/main.c",
};
