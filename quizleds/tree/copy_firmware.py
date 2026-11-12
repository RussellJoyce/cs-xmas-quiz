# Copies each tree build to the quiz server's firmware folder, as tree-<chip>.bin, so that
# the next "ltu" (update the trees) serves it. Runs after every build of either board.
# Written to a temporary name and renamed, so the server never serves half a file.

import os
import shutil

Import("env")

def copy_firmware(source, target, env):
    mcu = env.BoardConfig().get("build.mcu")
    dest_dir = os.path.join(env.subst("$PROJECT_DIR"), "..", "..", "nodeserver", "firmware")
    os.makedirs(dest_dir, exist_ok=True)
    dest = os.path.join(dest_dir, "tree-%s.bin" % mcu)
    tmp = dest + ".tmp"
    shutil.copyfile(str(target[0]), tmp)
    os.replace(tmp, dest)
    print("Copied to %s" % os.path.normpath(dest))

env.AddPostAction("$BUILD_DIR/${PROGNAME}.bin", copy_firmware)
