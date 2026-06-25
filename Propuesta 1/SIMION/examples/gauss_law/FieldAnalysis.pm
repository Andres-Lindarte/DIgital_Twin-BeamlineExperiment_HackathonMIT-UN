# Licenced under the terms of SIMION version 8 or the SIMION SL Toolkit
# (www.simion.com/sl). (c) 2006-2009 Scientific Instrument Services, Inc.
# D.Manura, 200606/20091230

package FieldAnalysis;
use strict;
use POSIX qw/acos ceil log10/;

my $pi = 3.141592653589793;

# utility - Normalizes vector ($x,$y,$z).
# (0,0,0) unmodified.
sub normalize_vector {
    my ($x,$y,$z) = @_;
    my $len = sqrt($x*$x + $y*$y + $z*$z);
    if ($len != 0) { $x /= $len; $y /= $len; $z /= $len; }
    return ($x, $y, $z);
}

# utility - Gets cross product of ($ax,$ay,$az) and ($bx,$by,$bz).
sub vector_cross {
    my ($ax,$ay,$az, $bx,$by,$bz) = @_;
    return ($ay*$bz - $az*$by,
            $az*$bx - $ax*$bz,
            $ax*$by - $ay*$bx);
}

# Sphere with center ($xc,$yc,$zc) and radius $r.
sub sphere {
    my ($xc,$yc,$zc, $r) = @_;

    my $rand = &sphere_distribution($xc, $yc, $zc, $r);
    my $area = 4 * $pi * $r**2;

    return {
        area => $area,
        rand => $rand
    };
}

# Cylinder with center ($xc,$yc) and radius $r on 2D X-Y plane.
# For 2D planar PAs only.
sub cylinder2d {
    my ($xc,$yc, $r) = @_;

    my $rand = &cylinder2d_distribution($xc, $yc, $r);
    my $area = $pi * $r**2;

    return {
        area => $area,
        rand => $rand
    };
}

# Cylinder with base centered at ($xc,$yc,$zc), vector
# normal to base ($nx,$ny,$nz), base radius $r, and
# lateral length $len.
# Normal ($nx,$ny,$nz) points inward toward second base.
#
# Example: &cylinder3d(0,0,0, 1,0,0, 5,10)
#   creates cylinder with axis in +X direction (1,0,0), with
#   one base of radius 5 centered at the origin (0,0,0) and the other base
#   centered at (0,0,0) + 10 * ((1,0,0) / |(1,0,0)|) = (10,0,0).
sub cylinder3d {
    my ($xc,$yc,$zc, $nx,$ny,$nz, $r, $len) = @_;

    my $rand = &cylinder3d_distribution($xc,$yc,$zc, $nx,$ny,$nz, $r, $len);
    my $area = 2 * ($pi * $r**2) + (2 * $pi * $r * $len);
    return {
        area => $area,
        rand => $rand
    };
}

# cylinder2d or cylinder3d
sub cylinder {
    if (@_ == 8) {
        return &cylinder3d(@_);
    }
    elsif (@_ == 3) {
        return &cylinder2d(@_);
    }
    else { die 'wrong number of arguments'; }
}

# Rectangular box with opposite corners ($x1,$y1) and ($x2,$y2) on 2D X-Y
# plane.  For 2D planar PAs only.
sub box2d {
    my ($x1,$y1, $x2,$y2) = @_;

    my $rand = &box2d_distribution($x1, $y1, $x2, $y2);

    my $dx = $x2 - $x1;
    my $dy = $y2 - $y1;
    my $area = 2 * (abs($dx) + abs($dy));

    return {
        area => $area,
        rand => $rand
    };
}

# Rectangular box with opposite corners ($x1,$y1,$z1) and ($x2,$y2,$z2).
sub box3d {
    my ($x1,$y1,$z1, $x2,$y2,$z2) = @_;

    my $rand = &box3d_distribution($x1, $y1, $z1, $x2, $y2, $z2);

    my $dx = $x2 - $x1;
    my $dy = $y2 - $y1;
    my $dz = $z2 - $z1;
    my $area = 2 * (abs($dy * $dz) + abs($dx * $dz) + abs($dx * $dy));

    return {
        area => $area,
        rand => $rand
    };
}

# box3d or box2d
sub box {
    if (@_ == 6) {
        return &box3d(@_);
    }
    elsif (@_ == 4) {
        return &box2d(@_);
    }
    else { die 'wrong number of arguments'; }
}


# Gets function that returns random point ($x,$y,$z), with
# normal vector ($ux,$uy,$uz), on surface of rectangular box
# with opposite corners ($x1,$y1) and ($x2,$y2) on 2D X-Y plane.
# Normal vectors point outward.
# For 2D planar PAs only.
sub box2d_distribution {
    my ($x1,$y1, $x2,$y2) = @_;

    # swap for correct order
    if ($x2 < $x1) { ($x1, $x2) = ($x2, $x1); }
    if ($y2 < $y1) { ($y1, $y2) = ($y2, $y1); }

    my $dx = $x2 - $x1;
    my $dy = $y2 - $y1;

    my $area_sum = $dx + $dy;

    return sub {
        my $a = rand();
        my $dir = $a > 0.5 ? +1 : -1;
        $a *= 2; $a-- if $a >= 1;
        my ($x, $y, $z, $ux, $uy, $uz);
        if ($a < $dx/$area_sum) {
            $x = ($dir > 0) ? $x2 : $x1;
            $y = rand() * $dy  + $y1;
            $z = 0;
            $ux = $dir;
            $uy = 0;
            $uz = 0;
        }
        else {
            $x = rand() * $dx  + $x1;
            $y = ($dir > 0) ? $y2 : $y1;
            $z = 0;
            $ux = 0;
            $uy = $dir;
            $uz = 0;
        }
        return ($x, $y, $z, $ux, $uy, $uz);
    };
}

# Gets function that returns random point ($x,$y,$z), with
# normal vector ($ux,$uy,$uz), on surface of rectangular box
# with opposite corners ($x1,$y1,$z1) and ($x2,$y2,$z2).
# Normal vectors point outward.
sub box3d_distribution {
    my ($x1,$y1,$z1, $x2,$y2,$z2) = @_;

    # swap for correct order
    if ($x2 < $x1) { ($x1, $x2) = ($x2, $x1); }
    if ($y2 < $y1) { ($y1, $y2) = ($y2, $y1); }
    if ($z2 < $z1) { ($z1, $z2) = ($z2, $z1); }

    my $dx = $x2 - $x1;
    my $dy = $y2 - $y1;
    my $dz = $z2 - $z1;

    my $areax = $dy*$dz;
    my $areay = $dx*$dz;
    my $areaz = $dx*$dy;
    my $area_sum = $areax + $areay + $areaz;

    return sub {
        my $a = rand();
        my $dir = $a > 0.5 ? +1 : -1;
        $a *= 2; $a-- if $a >= 1;
        my ($x, $y, $z, $ux, $uy, $uz);
        if ($a < $areax/$area_sum) {
            $x = ($dir > 0) ? $x2 : $x1;
            $y = rand() * $dy  + $y1;
            $z = rand() * $dz  + $z1;
            $ux = $dir;
            $uy = 0;
            $uz = 0;
        }
        elsif ($a < ($areax + $areay)/$area_sum) {
            $x = rand() * $dx  + $x1;
            $y = ($dir > 0) ? $y2 : $y1;
            $z = rand() * $dz + $z1;
            $ux = 0;
            $uy = $dir;
            $uz = 0;
        }
        else {
            $x = rand() * $dx + $x1;
            $y = rand() * $dy + $y1;
            $z = ($dir > 0) ? $z2 : $z1;
            $ux = 0;
            $uy = 0;
            $uz = $dir;
        }
        return ($x, $y, $z, $ux, $uy, $uz);
    };
}

# utility - Gets arbitrary orthogonally oriented unit vector ($ax,$ay,$az)
# not coinciding with ($x,$y,$z).  ($x,$y,$z) need not be normalized.
sub get_distant_axis {
    my ($x,$y,$z) = @_;
    my ($ax,$ay,$az);
    if (abs($x) >= abs($y) && abs($x) >= abs($z))    # X largest
    {   ($ax,$ay,$az) = (0,1,0); } # Y
    elsif (abs($y) >= abs($x) && abs($y) >= abs($z)) # Y largest
    {   ($ax,$ay,$az) = (0,0,1); } # Z
    else                                             # Z largest
    {   ($ax,$ay,$az) = (1,0,0); } # X
    return ($ax,$ay,$az);
  }

# Gets function that returns random point ($x,$y,$z), with
# normal vector ($nx,$ny,$nz), on surface of circle
# with origin ($xc,$yc,$zc), normal ($nx,$ny,$nz) and radius $r.
# Returned mormal vectors ($nx,$ny,$nz) are same as input.
sub circle3d_filled_distribution {
    my ($xc,$yc,$zc, $nx,$ny,$nz, $r) = @_;

    # new coordinate system unit vectors w,v,n (right-hand)
    my ($ax,$ay,$az) = &get_distant_axis($nx,$ny,$nz);
    my ($wx,$wy,$wz) = &normalize_vector(&vector_cross($ax,$ay,$az, $nx,$ny,$nz));
    my ($vx,$vy,$vz) = &vector_cross($nx,$ny,$nz, $wx,$wy,$wz);
         # n x w = v => w x v = n

    return sub {
        my ($w, $v);
        do { ($w,$v) = (rand(),rand()); } while ($w*$w + $v*$v > 1);
        my ($x,$y,$z) = ($xc+$r*($w*$wx+$v*$vx),
                         $yc+$r*($w*$wy+$v*$vy),
                         $zc+$r*($w*$wz+$v*$vz));
        return ($x,$y,$z, $nx,$ny,$nz);
    };
}

# Gets function that returns point ($x,$y,$z), with normal vectors
# ($ux,$uy,$uz), randomly distributed along circumference of circle
# with origin ($xc,$yc,$zc), normal ($nx,$ny,$nz) and radius $r.
# Normal vectors point outward.
sub circle3d_distribution {
    my ($xc,$yc,$zc, $nx,$ny,$nz, $r) = @_;

    # new coordinate system unit vectors w,v,n (right-hand)
    my ($ax,$ay,$az) = &get_distant_axis($nx,$ny,$nz);
    my ($wx,$wy,$wz) = &normalize_vector(&vector_cross($ax,$ay,$az, $nx,$ny,$nz));
    my ($vx,$vy,$vz) = &vector_cross($nx,$ny,$nz, $wx,$wy,$wz);
         # n x w = v => w x v = n

    return sub {
        my $theta = 2 * $pi * rand();
        my ($w, $v) = (cos($theta), sin($theta));
        my ($ux,$uy,$uz) = ($w*$wx + $v*$vx,
                            $w*$wy + $v*$vy,
                            $w*$wz + $v*$vz);

        my ($x,$y,$z) = ($xc + $r*$ux,
                         $yc + $r*$uy,
                         $zc + $r*$uz);
        return ($x,$y,$z, $ux,$uy,$uz);
    };
}

# Gets function that returns point ($x,$y,$z), with normal vectors
# ($ux,$uy,$uz), randomly distributed on surface of cylinder
# with origin ($xc,$yc,$zc), normal ($nx,$ny,$nz), radius $r,
# and length $z.  Normal ($nx,$ny,$nz) points inward toward second base.
# Normal vectors ($ux,$uy,$uz) point outward.
sub cylinder3d_distribution {
    my ($xc,$yc,$zc, $nx,$ny,$nz, $r, $len) = @_;

    ($nx,$ny,$nz) = &normalize_vector($nx,$ny,$nz);

    my $area_base = $pi * $r**2;
    my $area_lat  = 2 * $pi * $r * $len;
    my $area_sum = 2 * $area_base + $area_lat;

    my ($xd,$yd,$zd) = ($xc+$len*$nx,
                        $yc+$len*$ny,
                        $zc+$len*$nz);

    my $base1_dist  = &circle3d_filled_distribution($xc,$yc,$zc, -$nx,-$ny,-$nz, $r);
    my $base2_dist  = &circle3d_filled_distribution($xd,$yd,$zd,  $nx, $ny, $nz, $r);
    my $circle_dist = &circle3d_distribution(       $xc,$yc,$zc,  $nx, $ny, $nz, $r);

    return sub {
        my $a = rand();
        if ($a < $area_base/$area_sum) {
            return $base1_dist->();
        }
        elsif ($a < 2*$area_base/$area_sum) {
            return $base2_dist->();
        }
        else {
            my ($x,$y,$z, $ux,$uy,$uz) = $circle_dist->();
            my $ll = rand() * $len;
            ($x,$y,$z) = ($x+$ll*$nx,
                          $y+$ll*$ny,
                          $z+$ll*$nz);
            return ($x,$y,$z, $ux,$uy,$uz);
        }
    };
}


# Gets function that returns point ($x,$y,$z), with normal vectors
# ($ux,$uy,$uz), randomly distributed on surface of sphere
# with origin ($xc,$yc,$zc) and radius $r.
# Normal vectors point outward.
sub sphere_distribution {
    my ($xc,$yc,$zc, $r) = @_;
    my $c = 1 - cos($pi);

    # This is based on the more general uniformly random vector in
    # a cone (but with 180 degree vertex angle)
    # -- http://www.simion.com/info/Particle_Initial_Conditions
    # Note: partly based on FLY2 code.

    return sub {
        # Let a in [0, vertex_angle] be a random angle from the vertex axis.
        # The number of points in the cone having this a is proportional
        # to sin(a), so the probability distribution for a is
        # f(a) = sin(a)/(1 - cos(vertex_angle)).
        # t = math.random() is a uniform random variable in [0, 1).
        # From the fundamental transformation law of probabilities,
        # a = arccos(1 - t * (1 - cos(vertex_angle)))
        my $a = acos(1 - rand() * $c);

        # Rotation angle is a uniform random variable in [0, 2PI).
        my $rot = rand() * 2 * $pi;
 
        # create unit vector
        my $sina = sin($a);
        my $ux = cos($a);
        my $uy = $sina * cos($rot);
        my $uz = $sina * sin($rot);
        my $x = $xc + $ux * $r;
        my $y = $yc + $uy * $r;
        my $z = $zc + $uz * $r;
        return ($x, $y, $z, $ux, $uy, $uz);
    };
}

# Gets function that returns point ($x,$y,$z), with normal vectors
# ($ux,$uy,$uz), randomly distributed on lateral edge
# of cylinder in 2D X-Y plane with origin ($xc,$yc,$zc), radius $r,
# and axis in Z.
# Normal vectors point outward.
# For 2D planar PAs only.
sub cylinder2d_distribution {
    my ($xc,$yc, $r) = @_;

    return sub {
        # Generate random point and get unit normal vector
        my $theta = rand() * 2 * $pi;
        my $ux = cos($theta);
        my $uy = sin($theta);
        my $uz = 0;
        my $x = $xc + $ux * $r;
        my $y = $yc + $uy * $r;
        my $z = 0;
        return ($x, $y, $z, $ux, $uy, $uz);
    };
}

# Computes total charge inside given shape ($shape).
# Uses Gauss' Law.
# - pa is SIMION PA object
# - shape is the shape object defining the volume to use
# - mm_per_unit is the mm/gu scaling factor
# - min_coverage is the minimum coverage in points per gu.
#     A value of 1 indicates approximate 1 points per grid unit
#     surface.
# - max_fe is the maximum fractional error.
#     This is some small fraction of 1.
sub charge_from_gauss_law_display {
    my %params = @_;
    my $pa = $params{pa} || die 'pa not specified';
    my $shape = $params{shape} || die 'shape not specified';
    my $mm_per_unit = $params{mm_per_unit} || 1;
    my $min_coverage = $params{min_coverage} || 1.0;
    my $max_fe = $params{max_fe} || 1.0;

    my $smax_fe = sprintf("%0.1e", $max_fe);
    my $smin_coverage = sprintf("%0.1e", $min_coverage);

    print "Calculating total charge in volume...\n";
    print "with mm_per_unit=$mm_per_unit mm/gu,\n";
    print "     max fractional error=$smax_fe, min coverage=$smin_coverage\n";

    my $e0 = 8.8541878176E-12; # permittivity of free space (F/m)

    my $area = $shape->{area};
    my $rand = $shape->{rand};
    my $f = $e0 * $area * 1E-3 / $mm_per_unit; # note: 1E-3 m/mm.

    my $area_gu = $area / $mm_per_unit**2;

    my $last = 0;
    my $sum = 0;
    my $stdev_sum = 0;
    my $count = 0;
    while (1) {
        my $bcount = 0;
        my $bsum = 0;
        my $bsum2 = 0;
        for (1..100) {
            my ($x, $y, $z, $ux, $uy, $uz) = $rand->();
            my $xg = $x / $mm_per_unit;
            my $yg = $y / $mm_per_unit;
            my $zg = $z / $mm_per_unit;

            my ($ex, $ey, $ez) = $pa->field_real($xg, $yg, $zg);

            my $dflux = $ex*$ux + $ey*$uy + $ez*$uz;

            $bsum += $dflux;
            $bcount++;

            $bsum2 += $dflux**2;
        }
        my $bstdev = sqrt(($bsum2/$bcount) - ($bsum/$bcount)**2);
        my $bave = $bsum / $bcount;

        $sum += $bave;
        $stdev_sum += $bstdev;
        $count++;

        my $ave = $sum / $count;
        my $stdev = $stdev_sum / $count;

        my $charge = $f * $ave;
        my $charge_stdev = $f * $stdev / $mm_per_unit;
        my $charge_err = $charge_stdev / sqrt(100 * $count);

        my $fe = $charge_err / ($charge == 0 ? 1 : abs($charge));

        my $n = $count * 100;

        my $coverage = $n / $area_gu; # points per grid unit

        my $scharge = &scientific_notation($charge, $charge_err);
        my $scoverage = sprintf("%0.1e", $coverage);
        my $sfe = sprintf("%0.1e", $fe);
        print "charge=$scharge C (*) " .
              "[iteration=$n,fe=$sfe,coverage=$scoverage pts/gu]\n";

        last if $fe < $max_fe && $coverage > $min_coverage;
    }

    print "Convergence limits reached.\n";
    print "(*) Error bound reflects integration error only.\n";
}

# Formats number in scientific notation with error bound.
# e.g. "2.27810e-05 +/- 2.2e-09".
# Note: similar to the approach taken in Number::WithError.
# Further improvement may be possible.
sub scientific_notation {
    my ($value, $error) = @_;

    if ($error == 0) {
        return sprintf("%0.15e", $value);
    }

    $value = $error / 1000 if $value == 0;

    my $s = sprintf("%e", $error);
    $s =~ /e([+-]\d+)/ or die 'ASSERT';
    my $error_exponent = $1;

    my $sb = sprintf("%e", $value);
    $sb =~ /e([+-]\d+)/ or die 'ASSERT';
    my $value_exponent = $1;

    my $digits = $value_exponent - $error_exponent + 1;

    my $sc;
    if ($digits >= 0) {
        $sc = sprintf("%0.${digits}e", $value);
    }
    elsif ($digits == -1) {
        $sb =~ /([0-9])/ or die 'ASSERT';
        $sc = ($1 < 5) ? 0 : (($value > 0 ? 1 : -1) .
              sprintf("e%+03d", $value_exponent+1));
    }
    else {
        $sc = '0';
    }
    return sprintf("$sc +/- %0.1e", $error);
}

1
