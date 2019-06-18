#!/bin/bash

# package the build artifacts

set -ex

. "$(dirname $0)/utils.sh"

# Generate artifacts for release
mk_artifacts() {
    CARGO="$(builder)"
	"$CARGO" build --target "$TARGET" --release
}

# run from tmpdir, put results in $1/
# currently windows only, because other OS probably have a package manager
# also currently just a fixed version of each tool since it doesn't matter much
download_other_binaries() {
    outdir="$1"
    mkdir -p "$outdir/licenses"

    # ffmpeg
    wget -q https://ffmpeg.zeranoe.com/builds/win64/static/ffmpeg-4.1.3-win64-static.zip -O ffmpeg.zip
    unzip ffmpeg.zip
    cp ffmpeg-*/bin/{ffmpeg,ffprobe}.exe "$outdir"
    cp ffmpeg-*/LICENSE.txt "$outdir/licenses/ffmpeg"

    # xpdf
    wget -q https://xpdfreader-dl.s3.amazonaws.com/xpdf-tools-win-4.01.01.zip -O xpdf.zip
    unzip xpdf.zip
    cp xpdf-tools*/bin64/pdftotext.exe "$outdir/"
    cp xpdf-tools*/COPYING3 "$outdir/licenses/xpdf"
    
    wget -q https://github.com/jgm/pandoc/releases/download/2.7.3/pandoc-2.7.3-windows-x86_64.zip -O pandoc.zip
    unzip pandoc.zip
    cp pandoc-*/pandoc.exe "$outdir/"
    cp pandoc-*/COPYRIGHT.txt "$outdir/licenses/pandoc"

    wget -q https://github.com/BurntSushi/ripgrep/releases/download/11.0.1/ripgrep-11.0.1-x86_64-pc-windows-msvc.zip -O ripgrep.zip
    unzip ripgrep.zip
    cp rg.exe "$outdir/"

}

mk_tarball() {
    # When cross-compiling, use the right `strip` tool on the binary.
    local gcc_prefix="$(gcc_prefix)"
    # Create a temporary dir that contains our staging area.
    # $tmpdir/$name is what eventually ends up as the deployed archive.
    local tmpdir="$(mktemp -d)"
    local name="${PROJECT_NAME}-${TRAVIS_TAG}-${TARGET}"
    local staging="$tmpdir/$name"
    mkdir -p "$staging/"
    # mkdir -p "$staging"/{complete,doc}
    # The deployment directory is where the final archive will reside.
    # This path is known by the .travis.yml configuration.
    local out_dir="$(pwd)/deployment"
    mkdir -p "$out_dir"
    # Find the correct (most recent) Cargo "out" directory. The out directory
    # contains shell completion files and the man page.
    local cargo_out_dir="$(cargo_out_dir "target/$TARGET")"

    bin_ext=""
    if is_windows; then
        bin_ext=".exe"
    fi

    # Copy the binaries and strip it.
    for binary in rga rga-preproc; do
        cp "target/$TARGET/release/$binary$bin_ext" "$staging/$binary$bin_ext"
        # "${gcc_prefix}strip" "$staging/$binary"
    done
    # Copy the licenses and README.
    cp {README.md,LICENSE.md} "$staging/"
    # Copy documentation and man page.
    # cp {CHANGELOG.md,FAQ.md,GUIDE.md} "$staging/doc/"
    #if command -V a2x 2>&1 > /dev/null; then
    #  # The man page should only exist if we have asciidoc installed.
    #  cp "$cargo_out_dir/rg.1" "$staging/doc/"
    #fi
    # Copy shell completion files.
    # cp "$cargo_out_dir"/{rg.bash,rg.fish,_rg.ps1} "$staging/complete/"
    # cp complete/_rg "$staging/complete/"

    #if is_windows; then
        (cd "$tmpdir" && download_other_binaries "$name")
        (cd "$tmpdir" && 7za a "$out_dir/$name.7z" "$name")
    #else
    #    (cd "$tmpdir" && tar czf "$out_dir/$name.tar.gz" "$name")
    #fi
    rm -rf "$tmpdir"
}

main() {
    mk_artifacts
    mk_tarball
}

main
