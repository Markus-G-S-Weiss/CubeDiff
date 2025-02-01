#!/bin/bash
# diff_cube.sh - Compute the difference between the volumetric data in two cube files.
#
# Usage:
#   ./diff_cube.sh [--help] [--separate] file1.cube file2.cube
#
# The script produces a file named 'diff.cube' which consists of:
#   - The header (copied from file1.cube)
#   - The volumetric data differences computed as:
#         (value from file2.cube) - (value from file1.cube)
#
# If the flag --separate is provided, two additional files are generated:
#   diff_positive.cube: only positive values remain (negative values replaced by zero)
#   diff_negative.cube: only negative values remain (positive values replaced by zero)
#
# The header length is determined from file1.cube (6 + number of atoms as specified on line 3).

show_help() {
    cat <<EOF
Usage: $0 [--help] [--separate] file1.cube file2.cube

Compute the difference between the volumetric data of two cube files.

Arguments:
  file1.cube   The first cube file (used for the header and data subtraction).
  file2.cube   The second cube file (data from which values are subtracted).

Output:
  diff.cube          Contains the header (from file1.cube) and grid differences computed as:
                        (value from file2.cube) - (value from file1.cube)
  diff_positive.cube (if --separate is used): Only positive grid values remain; negative ones set to 0.
  diff_negative.cube (if --separate is used): Only negative grid values remain; positive ones set to 0.

Options:
  --help       Show this help message and exit.
  --separate   Create two additional cube files: one with positive data (negative set to 0) and one with negative data (positive set to 0).
EOF
}

# Process flags
separate=false
while [[ "$1" == --* ]]; do
  case "$1" in
    --help)
      show_help
      exit 0
      ;;
    --separate)
      separate=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Try '$0 --help' for more information."
      exit 1
      ;;
  esac
done

# Require exactly two arguments after flags are processed.
if [ "$#" -ne 2 ]; then
    echo "Error: Two cube files must be provided."
    echo "Try '$0 --help' for more information."
    exit 1
fi

file1="$1"
file2="$2"

# Determine the number of header lines from file1.
nhead=$(awk 'NR==3 { n=($1<0)? -$1 : $1; print 6+n; exit }' "$file1")
if [ -z "$nhead" ]; then
    echo "Error: Could not determine header length from $file1."
    exit 1
fi

# Create diff.cube:
#   1. Copy the header from file1.
#   2. Compute the difference (file2 - file1) for the volumetric data.
{
  head -n "$nhead" "$file1"
  paste <(tail -n +"$(( nhead + 1 ))" "$file2") <(tail -n +"$(( nhead + 1 ))" "$file1") | \
  awk '{
    # For each line, process the first half (from file2) and the second half (from file1)
    for (i = 1; i <= NF/2; i++) {
      diff = $i - $(i + NF/2);
      printf("%17.9E", diff);
    }
    print "";
  }'
} > diff.cube

echo "Output written to diff.cube"

# If the --separate flag was used, create two additional files.
if $separate; then
  # Produce diff_positive.cube: keep positive values, set negatives to zero.
  awk -v nhead="$nhead" '
  NR <= nhead { print; next }
  {
    for (i = 1; i <= NF; i++) {
      if ($i > 0)
        printf("%17.9E", $i);
      else
        printf("%17.9E", 0);
    }
    print "";
  }' diff.cube > diff_positive.cube

  # Produce diff_negative.cube: keep negative values, set positives to zero.
  awk -v nhead="$nhead" '
  NR <= nhead { print; next }
  {
    for (i = 1; i <= NF; i++) {
      if ($i < 0)
        printf("%17.9E", $i);
      else
        printf("%17.9E", 0);
    }
    print "";
  }' diff.cube > diff_negative.cube

  echo "Additional files written to diff_positive.cube and diff_negative.cube"
fi

