TERMUX_PKG_HOMEPAGE=http://clang.llvm.org/
TERMUX_PKG_DESCRIPTION="Modular compiler and toolchain technologies library"
_PKG_MAJOR_VERSION=3.9
TERMUX_PKG_VERSION=${_PKG_MAJOR_VERSION}.1
TERMUX_PKG_REVISION=3
TERMUX_PKG_SRCURL=http://llvm.org/releases/${TERMUX_PKG_VERSION}/llvm-${TERMUX_PKG_VERSION}.src.tar.xz
TERMUX_PKG_SHA256=1fd90354b9cf19232e8f168faf2220e79be555df3aa743242700879e8fd329ee
TERMUX_PKG_HOSTBUILD=true
TERMUX_PKG_RM_AFTER_INSTALL="
bin/bugpoint
bin/clang-check
bin/git-clang-format
bin/llvm-tblgen
bin/macho-dump
bin/sancov
bin/sanstats
bin/scan-build
bin/scan-view
lib/BugpointPasses.so
lib/libLTO.so
lib/LLVMHello.so
share/man/man1/scan-build.1
share/scan-build
share/scan-view
"
TERMUX_PKG_DEPENDS="binutils, ncurses, ndk-sysroot, ndk-stl, libgcc"
# Replace gcc since gcc is deprecated by google on android and is not maintained upstream.
# Conflict with clang versions earlier than 3.9.1-3 since they bundled llvm.
TERMUX_PKG_CONFLICTS="gcc, clang (<< 3.9.1-3)"
TERMUX_PKG_REPLACES=gcc
# See http://llvm.org/docs/CMake.html:
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
-DLLVM_ENABLE_PIC=ON
-DLLVM_BUILD_TESTS=OFF
-DLLVM_INCLUDE_TESTS=OFF
-DCLANG_INCLUDE_TESTS=OFF
-DCLANG_TOOL_C_INDEX_TEST_BUILD=OFF
-DC_INCLUDE_DIRS=$TERMUX_PREFIX/include
-DLLVM_LINK_LLVM_DYLIB=ON
-DPYTHON_EXECUTABLE=`which python2.7`
-DLLVM_TABLEGEN=$TERMUX_PKG_HOSTBUILD_DIR/bin/llvm-tblgen
-DCLANG_TABLEGEN=$TERMUX_PKG_HOSTBUILD_DIR/bin/clang-tblgen"
TERMUX_PKG_FORCE_CMAKE=yes

termux_step_post_extract_package () {
	CLANG_SRC_TAR=cfe-${TERMUX_PKG_VERSION}.src.tar.xz
	test ! -f $TERMUX_PKG_CACHEDIR/$CLANG_SRC_TAR && termux_download http://llvm.org/releases/${TERMUX_PKG_VERSION}/$CLANG_SRC_TAR \
		$TERMUX_PKG_CACHEDIR/$CLANG_SRC_TAR \
		e6c4cebb96dee827fa0470af313dff265af391cb6da8d429842ef208c8f25e63

	tar -xf $TERMUX_PKG_CACHEDIR/$CLANG_SRC_TAR -C tools
	mv tools/cfe-${TERMUX_PKG_VERSION}.src tools/clang
}

termux_step_host_build () {
	termux_setup_cmake
	cmake -G "Unix Makefiles" $TERMUX_PKG_SRCDIR \
		-DLLVM_BUILD_TESTS=OFF \
		-DLLVM_INCLUDE_TESTS=OFF
	make -j $TERMUX_MAKE_PROCESSES clang-tblgen llvm-tblgen
}

termux_step_pre_configure () {
	cd $TERMUX_PKG_BUILDDIR
	LLVM_DEFAULT_TARGET_TRIPLE=$TERMUX_HOST_PLATFORM
	if [ $TERMUX_ARCH = "arm" ]; then
		LLVM_TARGET_ARCH=ARM
		# See https://github.com/termux/termux-packages/issues/282
		LLVM_DEFAULT_TARGET_TRIPLE="armv7a-linux-androideabi"
	elif [ $TERMUX_ARCH = "aarch64" ]; then
		LLVM_TARGET_ARCH=AArch64
	elif [ $TERMUX_ARCH = "i686" ]; then
		LLVM_TARGET_ARCH=X86
	elif [ $TERMUX_ARCH = "x86_64" ]; then
		LLVM_TARGET_ARCH=X86
	else
		echo "Invalid arch: $TERMUX_ARCH"
		exit 1
	fi
        # see CMakeLists.txt and tools/clang/CMakeLists.txt
	TERMUX_PKG_EXTRA_CONFIGURE_ARGS+=" -DLLVM_DEFAULT_TARGET_TRIPLE=$LLVM_DEFAULT_TARGET_TRIPLE"
	TERMUX_PKG_EXTRA_CONFIGURE_ARGS+=" -DLLVM_TARGET_ARCH=$LLVM_TARGET_ARCH	-DLLVM_TARGETS_TO_BUILD=$LLVM_TARGET_ARCH"
}

termux_step_post_make_install () {
	cd $TERMUX_PREFIX/bin

	for tool in clang clang++ cc c++ cpp gcc g++ ${TERMUX_HOST_PLATFORM}-{clang,clang++,gcc,g++,cpp}; do
		ln -f -s clang-${_PKG_MAJOR_VERSION} $tool
	done
}
