# GNUplot script for plotting histogram of TOFs
# for ions that hit the detector.
# D.Manura, 2008-10.

set style data histograms
set boxwidth 0.5 relative
set style fill solid 1.0 border -1
set datafile separator "," 

bin = 0.004

plot [41.75:41.85] 'result.txt' using (bin*int($2/bin)):(2) smooth freq with boxes

pause mouse
