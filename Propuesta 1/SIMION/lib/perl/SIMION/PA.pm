# SIMION::PA (Perl)
# This module is documented in the SIMION supplemental documentation.
# version: 20110811
# (c) 2003-2011 Scientific Instrument Services, Inc. (SIMION 8.0/8.1 License)

package SIMION::PA;

use strict;
use Carp;

our $VERSION = '2.01';

#IMPROVE:support writing PATXT files?

sub new
{
    my $class = shift;
    my %params = @_;

    my $self = bless {error => undef, pasharp => undef}, $class;

    if(!defined $params{file}) {
        # defaults
        %params = (
            mode => -1,
            #IMPROVE:use constants to prevent typos?
            symmetry => 'planar',
            max_voltage => 100000,
            nx => 3,
            ny => 3,
            nz => 1,
            # mirror
            # mirror_x
            # mirror_y
            # mirror_z
            field_type => 'electrostatic',
            ng => 100,
            fast_adjustable => 0,
            dx_mm => 1,
            dy_mm => 1,
            dz_mm => 1,
            %params
        );

        if(!defined($params{mirror}) && !defined($params{mirror_x})
           && ! defined($params{mirror_y}) && !defined($params{mirror_z}))
        {
            $params{mirror_x} = 0;
            $params{mirror_y} = ($params{symmetry} eq 'cylindrical');
            $params{mirror_z} = 0;
        }
    }

    $self->set(%params);

    return $self;
}

sub header_string
{
    my $self = $_[0];
    my $text =
"begin_header\n" .
"    mode "            . $self->mode() . "\n" .
"    symmetry "        . $self->symmetry() . "\n" .
"    max_voltage "     . $self->max_voltage() . "\n" .
"    nx "              . $self->nx() . "\n" .
"    ny "              . $self->ny() . "\n" .
"    nz "              . $self->nz() . "\n" .
"    mirror_x "        . ($self->mirror_x() ? 1 : 0) . "\n" .
"    mirror_y "        . ($self->mirror_y() ? 1 : 0) . "\n" .
"    mirror_z "        . ($self->mirror_z() ? 1 : 0) . "\n" .
"    field_type "      . $self->field_type() . "\n" .
"    ng "              . $self->ng() . "\n" ;

    if ($self->mode() <= -2) {
        $text .=
"    dx_mm " . $self->dx_mm() . "\n" .
"    dy_mm " . $self->dy_mm() . "\n" .
"    dz_mm " . $self->dz_mm() . "\n" ;
    }

    $text .=
"    fast_adjustable " . ($self->fast_adjustable() ? 1 : 0) . "\n" .
"end_header\n" ;
    return $text;
}

sub load
{
    my($s, $path) = @_;

    open(my $fh, $path) or croak "Could not open PA file ($path): $!.";
    binmode($fh);
    my $buf;
    read($fh, $buf, 4) or croak "Failed reading PA file ($path): $!.";
    my ($mode) = unpack("i", $buf);
    if ($mode != -1 && $mode != -2) {
        croak "Unrecognized file format mode ($mode)";
    }
    read($fh, $buf, 4*5 + 8)
        or croak "Failed reading PA file ($path): $!.";
    my @hinfo = ($mode, unpack("idiiii", $buf));
    if ($mode <= -2) {
        read($fh, $buf, 8*3)
            or croak "Failed reading PA file ($path): $!.";
        push @hinfo, unpack("ddd", $buf);
    }
    else {
        push @hinfo, (1,1,1);
    }

    #IMPROVE: add underscores to attributes?
    $s->{mode} = $hinfo[0];
    $s->{symmetry} = $hinfo[1] ? 'planar' : 'cylindrical';

    $s->{max_voltage} = $hinfo[2];
    $s->{nx} = $hinfo[3];
    $s->{ny} = $hinfo[4];
    $s->{nz} = $hinfo[5];
    my $raw_mirror = $hinfo[6];
    $s->{mirror_x} = ($raw_mirror & 1);
    $s->{mirror_y} = (($raw_mirror >> 1) & 1);
    $s->{mirror_z} = (($raw_mirror >> 2) & 1);
    $s->{field_type} = (($raw_mirror >> 3) & 1) ? 'magnetic' : 'electrostatic';
    $s->{ng} = ($raw_mirror >> 4) & ((1 << 17) - 1);
    $s->{dx_mm} = $hinfo[7];
    $s->{dy_mm} = $hinfo[8];
    $s->{dz_mm} = $hinfo[9];

    $s->{fast_adjustable} = !!($path =~ /#$/s);

    my $fx = "d" x $s->{nx};
    my $num_points = $s->{nx} * $s->{ny} * $s->{nz};
    my $nx = $s->{nx};
    $s->{points}->[$num_points-1] = 0; # allocate
    for(my $n=0; $n < $num_points; $n+=$nx) {
        read($fh, $buf, 8 * $nx) or croak "Failed reading PA file ($path): $!";
        @{$s->{points}}[$n..$n+$nx-1] = unpack("d" x $s->{nx}, $buf);
    }
    close($fh);
}

sub save
{
    my($s, $path) = @_;

    open(my $pafile, ">$path") or croak "$! $path";
    binmode($pafile);

    # header
    my $raw_mirror = 0;
    $raw_mirror |= 1 if $s->mirror_x();
    $raw_mirror |= 2 if $s->mirror_y();
    $raw_mirror |= 4 if $s->mirror_z();
    $raw_mirror |= 8 if $s->{field_type} eq 'magnetic';
    if ($s->{ng} >= 1 && $s->{ng} <= 90000 && $s->{ng} == int($s->{ng})) {
        $raw_mirror |= ($s->{ng} << 4);
    }

    print $pafile pack("iidiiii",
        $s->mode(),
        ($s->{symmetry} eq 'planar') ? 1 : 0,
        $s->{max_voltage},
        $s->{nx}, $s->{ny}, $s->{nz},
        $raw_mirror
    );
    if ($s->mode() <= -2) {
        print $pafile pack("ddd", $s->{dx_mm}, $s->{dy_mm}, $s->{dz_mm});
    }

    my $nx = $s->{nx};
    my $fx = "d" x $nx;
    my $num_points = @{$s->{points}};
    for(my $n=0; $n<$num_points; $n+=$nx) {
        print $pafile pack($fx, @{$s->{points}}[$n..$n+$nx-1]);
    }

    # record stats in PA0 file.
    if(defined $s->{pasharp}) {
        $s->{pasharp}->nx() == $s->nx() && $s->{pasharp}->ny() == $s->ny()
                  && $s->{pasharp}->nz() == $s->nz()
            or croak "PA# dimensions does not match PA0 dimensions";

        # records first index of electrodes.
        my @first_idx = (-1) x 31;

        for(my $n=0; $n<$num_points; $n++) {

            my $fval = $s->{pasharp}->{points}->[$n];
            if($fval >= 2 * $s->{pasharp}->max_voltage()) { # electrode
                $fval -= 2 * $s->{pasharp}->max_voltage();

                my $ival = int($fval);
                if($ival == $fval && $ival >= 1 && $ival <= 30) { # fast adjustable
                    if($first_idx[$ival] == -1) {
                        #print "$ival $n\n";
                        $first_idx[$ival] = $n;
                    }
                }
                elsif($first_idx[0] == -1) { # fast scalable
                    $first_idx[0] = $n;
                }
            }
        }

        my $num_electrodes = ($first_idx[0] != -1) ? 1 : 0;
        for(my $n=1; $n<=30; $n++) {
            if($first_idx[$n] != -1) {
                $num_electrodes++;
            }
        }
 
        print $pafile pack("l", $num_electrodes);
        print $pafile pack("d", 10000.0);
        for(my $n=0; $n<=30; $n++) {
            print $pafile pack("l", $first_idx[$n]);
        }
        print $pafile pack("l", -1);
    }

    close($pafile);
}

sub fast_adjustable
{
    return $_[0]->{fast_adjustable} if @_ <= 1;
    my($self, $fast_adjustable) = @_;
    $self->{fast_adjustable} = !!$fast_adjustable;
}


sub field_type
{
    return $_[0]->{field_type} if @_ <= 1;
    my($self, $field_type) = @_;
    $self->check_field_type($field_type) or croak $self->error();
    $self->{field_type} = $field_type;
}

sub max_voltage
{
    return $_[0]->{max_voltage} if @_ <= 1;
    my($self, $max_voltage) = @_;
    $self->check_max_voltage($max_voltage) or croak $self->error();

    my $num_points = $self->{nx} * $self->{ny} * $self->{nz};

    my $old_max_voltage = $self->{max_voltage};
    my $diff = -2 * $self->{max_voltage} + 2 * $max_voltage;

    $self->{max_voltage} = $max_voltage;
    for my $n (0..$num_points-1) {
        if ($self->{points}->[$n] > $old_max_voltage) {
            $self->{points}->[$n] += $diff;
        }
    }
}

sub mirror
{
    if(@_ <= 1) { # get
        my $str = '';
        $str .= 'x' if $_[0]->{mirror_x};
        $str .= 'y' if $_[0]->{mirror_y};
        $str .= 'z' if $_[0]->{mirror_z};
        return $str;
    }
    else { # set
        my($self, $mirror) = @_;
        $self->check_mirror($mirror) or croak $self->error();
        $self->{mirror_x} = !!($mirror =~ /x/);
        $self->{mirror_y} = !!($mirror =~ /y/);
        $self->{mirror_z} = !!($mirror =~ /z/);
    }
}

sub mirror_x
{
    return $_[0]->{mirror_x} if @_ <= 1;
    my($self, $mirror_x) = @_;
    $self->{mirror_x} = !! $mirror_x;
}

sub mirror_y
{
    return $_[0]->{mirror_y} if @_ <= 1;
    my($self, $mirror_y) = @_;
    $self->check(nx => $self->{nx}, ny => $self->{ny}, nz => $self->{nz},
           symmetry => $self->{symmetry},
           mirror_x => $self->{mirror_x},
           mirror_y => $mirror_y,
           mirror_z => $self->{mirror_z},
    ) or croak $self->error();
    $self->{mirror_y} = !! $mirror_y;
}

sub mirror_z
{
    return $_[0]->{mirror_z} if @_ <= 1;
    my($self, $mirror_z) = @_;
    $self->check(nx => $self->{nx}, ny => $self->{ny}, nz => $self->{nz},
           symmetry => $self->{symmetry},
           mirror_x => $self->{mirror_x},
           mirror_y => $self->{mirror_y},
           mirror_z => $mirror_z,
    ) or croak $self->error();
    $self->{mirror_z} = !! $mirror_z;
}

sub mode
{
    if (@_ <= 1) {
        my $mode = $_[0]->{mode};
        $mode = -2 if $mode == -1 && ($_[0]->{dx_mm} != 1 ||
                                      $_[0]->{dy_mm} != 1 ||
                                      $_[0]->{dz_mm} != 1);
        return $mode;
    }
    my($self, $mode) = @_;
    croak $self->error() if !$self->check_mode($mode);
    $self->{mode} = $mode;
}

sub ng
{
    return $_[0]->{ng} if @_ <= 1;
    my($self, $ng) = @_;
    $self->check_ng($ng) or croak $self->error();
    $self->{ng} = $ng;
}

sub num_points
{
    croak "Invalid number of arguments" if @_ != 1;
    my $self = $_[0];
    return $self->{nx} * $self->{ny} * $self->{nz};
}

sub num_voxels
{
    croak "Invalid number of arguments" if @_ != 1;
    my $self = $_[0];
    my $num = ($self->{nx} - 1) * ($self->{ny} - 1);
    $num *= ($self->{nz} - 1) if $self->{nz} != 1;
    return $num;
}

sub nx
{
    return $_[0]->{nx} if @_ <= 1;
    my($self, $nx) = @_;
    $self->check(nx => $nx, ny => $self->{ny}, nz => $self->{nz},
           symmetry => $self->{symmetry},
           mirror_x => $self->{mirror_x},
           mirror_y => $self->{mirror_y},
           mirror_z => $self->{mirror_z}
    ) or croak $self->error();
    $self->size($nx, $self->ny(), $self->nz());
}

sub ny
{
    return $_[0]->{ny} if @_ <= 1;
    my($self, $ny) = @_;
    $self->check(nx => $self->{nx}, ny => $ny, nz => $self->{nz},
           symmetry => $self->{symmetry},
           mirror_x => $self->{mirror_x},
           mirror_y => $self->{mirror_y},
           mirror_z => $self->{mirror_z}
    ) or croak $self->error();
    $self->size($self->nx(), $ny, $self->nz());
}

sub nz
{
    return $_[0]->{nz} if @_ <= 1;
    my($self, $nz) = @_;
    $self->check(nx => $self->{nx}, ny => $self->{ny}, nz => $nz,
           symmetry => $self->{symmetry},
           mirror_x => $self->{mirror_x},
           mirror_y => $self->{mirror_y},
           mirror_z => $self->{mirror_z}
    ) or croak $self->error();
    $self->size($self->{nx}, $self->{ny}, $nz);
}

sub pasharp
{
    return $_[0]->{pasharp} if @_ <= 1;
    my($self, $pasharp) = @_;
    $self->{pasharp} = $pasharp;
}

sub set
{
    my($self, %params) = @_;

    if(defined $params{file}) {
        croak "Named parameter 'file' cannot coexist with other named parameters."
            if keys %params != 1;
        $self->load($params{file});
    }
    else {
        foreach my $key (keys %params) {
            croak "Named parameter 'file' cannot coexist with other named parameters."
                if $key eq 'file';
            if($key !~ /^(?:
                mode|symmetry|max_voltage|nx|ny|nz|mirror|mirror_x|mirror_y|mirror_z|
                field_type|ng|dx_mm|dy_mm|dz_mm|fast_adjustable
            )$/xs) {
                croak "Invalid key ($key) passed into PA:new().";
            }
        }

        # aliases
        if(defined($params{mirror})) {
            croak "mirror and mirror_x named parameters cannot coexist."
                if defined($params{mirror_x});
            croak "mirror and mirror_y named parameters cannot coexist."
                if defined($params{mirror_y});
            croak "mirror and mirror_z named parameters cannot coexist."
                if defined($params{mirror_z});
            ($params{mirror_x}, $params{mirror_y}, $params{mirror_z}) =
                &_parse_mirror($params{mirror});
        }

        # defaults
        $params{mirror_y} = 1
            if &_def($params{symmetry}) eq 'cylindrical' &&
               !defined($params{mirror_y});

        # checks
        $self->check_mode($params{mode}) or croak $self->error()
            if defined $params{mode};
        $self->check_max_voltage($params{max_voltage}) or croak $self->error()
            if defined $params{max_voltage};
        $self->check_field_type($params{field_type}) or croak $self->error()
            if defined $params{field_type};
        $self->check_ng($params{ng}) or croak $self->error()
            if defined $params{ng};
        $self->check_symmetry($params{symmetry}) or croak $self->error()
            if defined $params{symmetry};
        $self->check_dx_mm($params{dx_mm}) or croak $self->error()
            if defined $params{dx_mm};
        $self->check_dy_mm($params{dy_mm}) or croak $self->error()
            if defined $params{dy_mm};
        $self->check_dz_mm($params{dz_mm}) or croak $self->error()
            if defined $params{dz_mm};

        if(defined($params{mirror_x}) || defined($params{mirror_y})
            || defined($params{mirror_z}))
        {
            $params{mirror_x} = $self->{mirror_x} if !defined($params{mirror_x});
            $params{mirror_y} = $self->{mirror_y} if !defined($params{mirror_y});
            $params{mirror_z} = $self->{mirror_z} if !defined($params{mirror_z});
            my $mirror_str = '';
            $mirror_str .= 'x' if $params{mirror_x};
            $mirror_str .= 'y' if $params{mirror_y};
            $mirror_str .= 'z' if $params{mirror_z};

            $self->check_mirror($mirror_str) or croak $self->error();
        }

        if(defined($params{nx}) || defined($params{ny}) || defined($params{nz})) {
            $params{nx} = $self->{nx} if !defined($params{nx});
            $params{ny} = $self->{ny} if !defined($params{ny});
            $params{nz} = $self->{nz} if !defined($params{nz});
            $self->check_size($params{nx}, $params{ny}, $params{nz}) or croak $self->error();
        }
        $params{symmetry} = $self->{symmetry} if !defined($params{symmetry});
        $params{mirror_x} = $self->{mirror_x} if !defined($params{mirror_x});
        $params{mirror_y} = $self->{mirror_y} if !defined($params{mirror_y});
        $params{mirror_z} = $self->{mirror_z} if !defined($params{mirror_z});
        $params{nx} = $self->{nx} if !defined($params{nx});
        $params{ny} = $self->{ny} if !defined($params{ny});
        $params{nz} = $self->{nz} if !defined($params{nz});
        my @checks;
        push @checks, 'nx', $params{nx};
        push @checks, 'ny', $params{ny};
        push @checks, 'nz', $params{nz};
        push @checks, 'symmetry', $params{symmetry};
        push @checks, 'mirror_x', $params{mirror_x};
        push @checks, 'mirror_y', $params{mirror_y};
        push @checks, 'mirror_z', $params{mirror_z};
        $self->check(@checks) or croak $self->error();

        # assert: no throws below this point.

        # set
        $self->{mode} = $params{mode} if defined $params{mode};
        $self->{max_voltage} = $params{max_voltage} if defined $params{max_voltage};
        $self->{field_type} = $params{field_type} if defined $params{field_type};
        $self->{ng} = $params{ng} if defined $params{ng};
        $self->{fast_adjustable} = !! $params{fast_adjustable}
            if defined $params{fast_adjustable};
        $self->{symmetry} = $params{symmetry} if defined $params{symmetry};
        $self->{mirror_x} = $params{mirror_x} if defined $params{mirror_x};
        $self->{mirror_y} = $params{mirror_y} if defined $params{mirror_y};
        $self->{mirror_z} = $params{mirror_z} if defined $params{mirror_z};
        $self->size($params{nx}, $params{ny}, $params{nz})  # no raise due to check_size
            if defined($params{nx}) &&
               ($params{nx} != $self->{nx} ||
                $params{ny} != $self->{ny} ||
                $params{nz} != $self->{nz});
        $self->{dx_mm} = $params{dx_mm} if defined $params{dx_mm};
        $self->{dy_mm} = $params{dy_mm} if defined $params{dy_mm};
        $self->{dz_mm} = $params{dz_mm} if defined $params{dz_mm};
    }
}

sub size
{
    my $self = $_[0];
    return ($self->{nx}, $self->{ny}, $self->{nz}) if @_ <= 1;
    my($self, $nx, $ny, $nz) = @_;
    $nz = 1 if !defined($nz);

    $self->check(nx => $nx, ny => $ny, nz => $nz, symmetry => $self->{symmetry},
           mirror_x => $self->{mirror_x},
           mirror_y => $self->{mirror_y},
           mirror_z => $self->{mirror_z}
    ) or croak $self->error();

    $self->{nx} = $nx;
    $self->{ny} = $ny;
    $self->{nz} = $nz;

    $self->{points} = [(0) x ($nx * $ny * $nz)];

}

sub symmetry
{
    return $_[0]->{symmetry} if @_ <= 1;
    my ($self, $symmetry) = @_;
    
    $self->check(nx => $self->{nx}, ny => $self->{ny}, nz => $self->{nz},
           symmetry => $symmetry,
           mirror_x => $self->{mirror_x},
           mirror_y => $self->{mirror_y},
           mirror_z => $self->{mirror_z}
    ) or croak $self->error();
    $self->{symmetry} = $symmetry;
}


sub dx_mm
{
    return $_[0]->{dx_mm} if @_ <= 1;
    my($self, $dx_mm) = @_;
    $self->check_dx_mm($dx_mm) or croak $self->error();
    $self->{dx_mm} = $dx_mm;
}

sub dy_mm
{
    return $_[0]->{dy_mm} if @_ <= 1;
    my($self, $dy_mm) = @_;
    $self->check_dy_mm($dy_mm) or croak $self->error();
    $self->{dy_mm} = $dy_mm;
}

sub dz_mm
{
    return $_[0]->{dz_mm} if @_ <= 1;
    my($self, $dz_mm) = @_;
    $self->check_dz_mm($dz_mm) or croak $self->error();
    $self->{dz_mm} = $dz_mm;
}


sub inside
{
    my($self, $x, $y, $z) = @_;
    my $yes = ($x >= 0 && $x < $self->{nx} &&
               $y >= 0 && $y < $self->{ny} &&
               $z >= 0 && $z < $self->{nz});
    return $yes;
}

sub inside_real
{
    my($self, $x, $y, $z) = @_;

    my $yes = 0;
    if($self->{symmetry} eq 'planar') {
        $yes =
            (($x >= 0.0) ? ($x <= $self->{nx}-1) : $self->mirror_x() ? (-$x <= $self->{nx}-1) : 0) &&
            (($y >= 0.0) ? ($y <= $self->{ny}-1) : $self->mirror_y() ? (-$y <= $self->{ny}-1) : 0) &&
            (  ($self->{nz} == 1) || # infinite extent
               (($z >= 0.0) ? ($z <= $self->{nz}-1) : $self->mirror_z() ? (-$z <= $self->{nz}-1) : 0)
            )
        ;
    }
    elsif($self->{symmetry} eq 'cylindrical') {
        my $r = sqrt($y*$y + $z*$z);
        $yes = $self->_inside_cylindrical_real($x, $r);
    }
    else { die "internal error: bad symmetry ($self->{symmetry})"; }
    return $yes;
}


sub voxel_inside
{
    my($self, $x, $y, $z) = @_;

    return $x >= 0 && $x + 1 < $self->{nx} &&
           $y >= 0 && $y + 1 < $self->{ny} &&
           ($self->{nz} == 1 ? $z == 0 : $z >= 0 && $z + 1 < $self->{nz});
}


sub clear_points
{
    my $self = $_[0];
    for(my $n=0; $n < self->num_points(); $n++) {
        $self->{points}->[$n] = 0.0;
    }
}

sub electrode
{
    # my($self, $x, $y, $x, $is_electrode) = @_;
    my $self = $_[0];

    $_[3] = 0 if ! defined $_[3];
    $self->inside(@_[1..3]) or $self->_fail_point(@_[1..3]);

    my $p = $self->{points};
    my $pos = ($_[3] * $self->{ny} + $_[2]) * $self->{nx} + $_[1];

    if(@_ < 5) { # get
        return ($p->[$pos] > $self->{max_voltage});
    }
    else { # set
        if($p->[$pos] > $self->{max_voltage}) {
            $p->[$pos] -= 2 * $self->{max_voltage} if !$_[4];
        }
        else {
            $p->[$pos] += 2 * $self->{max_voltage} if $_[4];
        }
    }

}

sub field
{
    my($self, $x, $y, $z) = @_;

    if(@_< 5) { # get
        $self->inside($x,$y,$z) or $self->_fail_point($x,$y,$z);
        return &field_real(@_);
    }
    else { # set
        &_set_field(@_);
    }

}


sub field_real
{
    my($self, $x, $y, $z) = @_;

    $z = 0 if ! defined $z;
    $self->inside_real($x,$y,$z) or $self->_fail_point($x,$y,$z);

    if($self->{symmetry} eq 'cylindrical') {
        my $r = sqrt($y*$y + $z*$z);

        #IMPROVE: is there a better way to handle boundary conditions?
        my $xm = $x - 0.5;
        my $min_x = $self->mirror_x() ? -($self->{nx}-1) : 0;
        if($xm < $min_x) { $xm = $min_x; }

        my $xp = $x + 0.5;
        if($xp > $self->{nx}-1) { $xp = $self->{nx}-1; }

        my $rm = $r - 0.5;
        my $min_r = -($self->{ny}-1);
        if($rm < $min_r) { $rm = $min_r; } # won't occur?

        my $rp = $r + 0.5;
        if($rp > $self->{ny}-1) { $rp = $self->{ny}-1; }

        # FIX:Q: should the sampling be done before or after
        # applying cylindrical symmetry?
        my $V2 = $self->potential_real($xp, $r,  0.0);
        my $V1 = $self->potential_real($xm, $r,  0.0);
        my $V4 = $self->potential_real($x,  $rp, 0.0);
        my $V3 = $self->potential_real($x,  $rm, 0.0);

        # print "$V1, $V2, $V3, $V4\n";

        my $Ex = ($V1 - $V2) / ($xp - $xm);
        my $Er = ($V3 - $V4) / ($rp - $rm);
        my $Ey = $Er * ($r != 0 ? $y/$r : 1.0);
        my $Ez = $Er * ($r != 0 ? $z/$r : 0.0);
        if($self->{field_type} eq 'magnetic') {
            $Ex *= $self->{ng};
            $Ey *= $self->{ng};
            $Ez *= $self->{ng};
            $Er *= $self->{ng};
        }
        return ($Ex, $Ey, $Ez);
    }
    else { # planar
        #IMPROVE:is there a better way to handle boundary conditions?
        my $xm = $x - 0.5;
        my $min_x = $self->mirror_x() ? -($self->{nx}-1) : 0;
        if($xm < $min_x) { $xm = $min_x; }

        my $xp = $x + 0.5;
        if($xp > $self->{nx}-1) { $xp = $self->{nx}-1; }

        my $ym = $y - 0.5;
        my $min_y = $self->mirror_y() ? -($self->{ny}-1) : 0;
        if($ym < $min_y) { $ym = $min_y; }

        my $yp = $y + 0.5;
        if($yp > $self->{ny}-1) { $yp = $self->{ny}-1; }

        my $zm = $z - 0.5;
        my $min_z = $self->mirror_z() ? -($self->{nz}-1) : 0;
        if($zm < $min_z) { $zm = $min_z; }

        my $zp = $z + 0.5;
        if($zp > $self->{nz}-1) { $zp = $self->{nz}-1; }
        my $V2 = $self->potential_real($xp, $y,  $z);
        my $V1 = $self->potential_real($xm, $y,  $z);
        my $V4 = $self->potential_real($x,  $yp, $z);
        my $V3 = $self->potential_real($x,  $ym, $z);
        my $V5 = 0.0;
        my $V6 = 0.0;
        if($self->{nz} != 1) {
            $V6 = $self->potential_real($x, $y, $zp);
            $V5 = $self->potential_real($x, $y, $zm);
        }
        my $Ex = ($V1 - $V2) / ($xp - $xm);
        my $Ey = ($V3 - $V4) / ($yp - $ym);
        my $Ez = ($self->{nz} == 1) ? 0.0 : ($V5 - $V6) / ($zp - $zm);

        if($self->{field_type} eq 'magnetic') {
            $Ex *= $self->{ng};
            $Ey *= $self->{ng};
            $Ez *= $self->{ng};
        }
        return ($Ex, $Ey, $Ez);
    }
}

sub raw
{
    # ($self, $x, $y, $z, $val) = @_;
    my $self = $_[0];

    $_[3] = 0 if ! defined $_[3];
    $self->inside(@_[1..3]) or $self->_fail_point(@_[1..3]);

    my $pos = ($_[3] * $self->{ny} + $_[2]) * $self->{nx} + $_[1];

    if(@_ < 5) { # get
        return $self->{points}->[$pos];
    }
    else { # set
        $self->{points}->[$pos] = $_[4];
    }

}

sub point
{
    # my($pa, $x, $y, $z, $is_electrode, $pot) = @_;
    my $self = $_[0];

    $_[3] = 0 if ! defined $_[3];
    $self->inside(@_[1..3]) or $self->_fail_point(@_[1..3]);

    my $p = $self->{points};

    my $pos = ($_[3] * $self->{ny} + $_[2]) * $self->{nx} + $_[1];

    $_[5] = 0 if defined($_[4]) && !defined($_[5]);

    if(@_ < 5) { # get
        my $pot = $p->[$pos];
        my $is_electrode = ($pot > $self->{max_voltage});
        $pot -= 2 * $self->{max_voltage} if $is_electrode;
        return ($is_electrode, $pot);
    }
    else { # set
        if ($_[5] > $self->{max_voltage}) {
            $self->max_voltage($_[5] * 2.0);
        }
        $p->[$pos] = $_[5];
        $p->[$pos] += 2 * $self->{max_voltage} if $_[4];
    }
}

sub potential
{
    # my($pa, $x, $y, $z, $pot) = @_;
    my $self = $_[0];

    $_[3] = 0 if ! defined $_[3];
    $self->inside(@_[1..3]) or $self->_fail_point(@_[1..3]);

    my $p = $self->{points};

    my $pos = ($_[3] * $self->{ny} + $_[2]) * $self->{nx} + $_[1];
    my $is_electrode = ($p->[$pos] > $self->{max_voltage});

    if(@_ < 5) { # get
        my $val = $p->[$pos];
        $val -= 2 * $self->{max_voltage} if $is_electrode;
        return $val;
    }
    else { # set
        if ($_[4] > $self->{max_voltage}) {
            $self->max_voltage($_[4] * 2.0);
        }
        $p->[$pos] = $_[4];
        $p->[$pos] += 2 * $self->{max_voltage} if $is_electrode;
    }
}

sub potential_real
{
    my($self, $x, $y, $z) = @_;

    $z = 0 if ! defined $z;
    $self->inside_real($x,$y,$z) or $self->_fail_point($x,$y,$z);

    my $xeff = ($x < 0) ? -$x : $x;  # if mirroring
    my $yeff = ($y < 0) ? -$y : $y;
    my $zeff = ($z < 0) ? -$z : $z;

    my $p = 0.0;
    if($self->{symmetry} eq 'planar') {
        if($self->{nz} == 1) { # 2D
            my $xi = int($xeff);
            my $yi = int($yeff);

            my $wx = $xeff - $xi;
            my $wy = $yeff - $yi;
            # note the checks on wx and wy to protect against cases where
            # xi + 1 == nx or yi + 1 == ny.
            $p =
                (1-$wx) * (1-$wy) *              $self->potential($xi, $yi, 0) +
                   $wx  * (1-$wy) * (($wx != 0) ? $self->potential($xi+1, $yi,   0) : 0.0) +
                (1-$wx) *    $wy  * (($wy != 0) ? $self->potential($xi,   $yi+1, 0) : 0.0) +
                   $wx  *    $wy  * (($wx != 0 &&
                                    $wy != 0) ? $self->potential($xi+1, $yi+1, 0) : 0.0)
            ;
        }
        else { # 3D
            my $xi = int($xeff);
            my $yi = int($yeff);
            my $zi = int($zeff);

            my $wx = $xeff - $xi;
            my $wy = $yeff - $yi;
            my $wz = $zeff - $zi;

            # note the checks on wx, wy, and wz to protect against cases where
            # xi + 1 == nx, yi + 1 == ny, or zi + 1 == nz.
            $p =
                (1-$wx)*(1-$wy)*(1-$wz)*$self->potential($xi, $yi, $zi) +
                   $wx *(1-$wy)*(1-$wz)*(($wx != 0) ? $self->potential($xi+1, $yi,   $zi) : 0.0) +
                (1-$wx)*   $wy *(1-$wz)*(($wy != 0) ? $self->potential($xi,   $yi+1, $zi) : 0.0) +
                   $wx *   $wy *(1-$wz)*(($wx != 0 &&
                                       $wy != 0) ? $self->potential($xi+1, $yi+1, $zi) : 0.0) +

                (1-$wx)*(1-$wy)*   $wz *(($wz != 0) ? $self->potential($xi, $yi, $zi+1) : 0.0) +
                   $wx *(1-$wy)*   $wz *(($wx != 0 &&
                                       $wz != 0) ? $self->potential($xi+1, $yi,   $zi+1) : 0.0) +
                (1-$wx)*   $wy *   $wz *(($wy != 0 &&
                                       $wz != 0) ? $self->potential($xi,   $yi+1, $zi+1) : 0.0) +
                   $wx *   $wy *   $wz *(($wx != 0 &&
                                       $wy != 0 &&
                                       $wz != 0) ? $self->potential($xi+1, $yi+1, $zi+1) : 0.0)
            ;
        }
    }
    elsif($self->{symmetry} eq 'cylindrical') {
        my $r = sqrt($y*$y + $z*$z);

        my $xi = int($xeff);
        my $ri = int($r);
        my $wx = $xeff - $xi;
        my $wr = $r - $ri;
        # note the checks on wx and wr to protect against cases where
        # xi + 1 == nx or ri + 1 == nr.
        $p =
            (1-$wx) * (1-$wr) * $self->potential($xi, $ri, 0) +
               $wx  * (1-$wr) * (($wx != 0) ? $self->potential($xi+1, $ri,   0) : 0.0) +
            (1-$wx) *    $wr  * (($wr != 0) ? $self->potential($xi,   $ri+1, 0) : 0.0) +
               $wx  *    $wr  * (($wx != 0 &&
                                $wr != 0) ? $self->potential($xi+1, $ri+1, 0) : 0.0)
        ;
    }
    else { die "internal error: bad symmetry ($self->{symmetry})"; }

    return $p;
}

sub solid
{
    my($self, $x, $y, $z, $is_electrode, $potential) = @_;

    $z = 0 if ! defined $z;
    $self->voxel_inside($x,$y,$z) or croak "voxel ($x,$y,$z) out of bounds.";

    if(@_ < 5) { # get
        if($self->{nz} == 1) { # 2D planar or cylindrical
            my $electrode =
                $self->electrode($x,   $y,   $z) &&
                $self->electrode($x+1, $y,   $z) &&
                $self->electrode($x,   $y+1, $z) &&
                $self->electrode($x+1, $y+1, $z);
            return $electrode;
        }
        else { # 3D
            my $electrode =
                $self->electrode($x,   $y,   $z) &&
                $self->electrode($x+1, $y,   $z) &&
                $self->electrode($x,   $y+1, $z) &&
                $self->electrode($x+1, $y+1, $z) &&
                $self->electrode($x,   $y,   $z+1) &&
                $self->electrode($x+1, $y,   $z+1) &&
                $self->electrode($x,   $y+1, $z+1) &&
                $self->electrode($x+1, $y+1, $z+1);
            return $electrode;
        }
    }
    else { # set
        my $p = $self->{points};
        my $raw = 2 * $self->{max_voltage} + $potential;
        if($self->{nz} == 1) { # 2D planar or cylindrical
            my $n = $y * $self->{nx} + $x;
            $p->[$n]                   = $raw;
            $p->[$n + 1]               = $raw;
            $p->[$n + $self->{nx}]     = $raw;
            $p->[$n + $self->{nx} + 1] = $raw;
        }
        else { # 3D
            my $n = ($z * $self->{ny} + $y) * $self->{nx} + $x;

            $p->[$n]                   = $raw;
            $p->[$n + 1]               = $raw;
            $p->[$n + $self->{nx}]     = $raw;
            $p->[$n + $self->{nx} + 1] = $raw;
            $p->[$n += $self->{ny} * $self->{nx}] = $raw;
            $p->[$n + 1]               = $raw;
            $p->[$n + $self->{nx}]     = $raw;
            $p->[$n + $self->{nx} + 1] = $raw;
        }
    }
}

#IMPROVE: check that integer params are integers?

sub _def
{
    return defined($_[0]) ? $_[0] : '';
}

sub _fail_point
{
    my($self, $x, $y, $z) = @_;
    croak "point ($x,$y,$z) out of bounds ($self->{nx},$self->{ny},$self->{nz}).";
}

sub _parse_mirror
{
    my $mirror = $_[0];
    unless($mirror =~ /^(x?)(y?)(z?)$/s) {
        croak "Invalid mirroring ($mirror).";
    }
    return ($1 ne '', $2 ne '', $3 ne '');
}

sub _set_field
{
    my($self, $x, $y, $z, $field_x, $field_y, $field_z) = @_;

    $z = 0 if !defined($z);
    $field_z = 0 if !defined($field_z);

    # perform numerical integration to solve the following for V:
    #
    #   E = - grad(V)
    #
    # This is done by the line integral:
    #
    #   V(x,y,z) = V(0,0,0) + line_integral_{C} E * n ds
    #
    # where C is an arbitrary path from (0,0,0) to (x,y,z).  For
    # each point (x,y,z), we actually do a weighted average of all
    # lattice paths (0,0,0) to (x,y,z) of length x+y+z.  In this
    # algorithm, the trapezoidal rule is used for the numerical
    # integration due to a nice algorithm requiring only O(1)
    # additional memory usage.
    #
    # Currently, V(0,0,0) is assumed to be zero.

    my $is_electrode = 0;

    if($self->field_type() eq 'magnetic') {
        $field_x /= $self->ng();
        $field_y /= $self->ng();
        $field_z /= $self->ng();
    }

    if($x != $self->nx() - 1) {
        $self->point($x + 1, $y, $z, 0,
                   $self->raw($x + 1, $y, $z) - $field_x);
    }
    if($y != $self->ny() - 1) {
        $self->point($x, $y + 1, $z, 0,
                   $self->raw($x, $y + 1, $z) - $field_y);
    }
    if($z != $self->nz() - 1) {
        $self->point($x, $y, $z + 1, 0,
                   $self->raw($x, $y, $z + 1) - $field_z);
    }

    if($x != 0 && $y != 0 && $z != 0) {
        my $val =
            ($self->potential($x-1, $y,   $z) +
             $self->potential($x,   $y-1, $z) +
             $self->potential($x,   $y,   $z-1)) / 3.0 +
            ($self->raw($x,   $y,   $z) -
             $field_x - $field_y - $field_z) / 6.0
        ;
        $self->point($x, $y, $z, $is_electrode, $val);
    }
    elsif($x != 0 && $y != 0) { # z == 0
        my $val = 
            ($self->potential($x-1, $y,   $z) +
             $self->potential($x,   $y-1, $z)) / 2.0 + 
            ($self->raw($x,   $y,   $z) -
             $field_x - $field_y) / 4.0
        ;
        $self->point($x, $y, $z, $is_electrode, $val);
    }
    elsif($x != 0 && $z != 0) { # y == 0
        my $val = 
            ($self->potential($x-1, $y,   $z) +
             $self->potential($x,   $y,   $z-1)) / 2.0 + 
            ($self->raw($x,   $y,   $z) -
             $field_x - $field_z) / 4.0
        ;
        $self->point($x, $y, $z, $is_electrode, $val);
    }
    elsif($y != 0 && $z != 0) { # x == 0
        my $val = 
            ($self->potential($x,   $y-1, $z) +
             $self->potential($x,   $y,   $z-1)) / 2.0 + 
            ($self->raw($x,   $y,   $z) -
             $field_y - $field_z) / 4.0
        ;
        $self->point($x, $y, $z, $is_electrode, $val);
    }
    elsif($z != 0) { # x == 0 && y == 0
        my $val = 
             $self->potential($x,   $y,   $z-1) +
            ($self->raw($x,   $y,   $z) -
             $field_z) / 2.0
        ;
        $self->point($x, $y, $z, $is_electrode, $val);
    }
    elsif($y != 0) { # x == 0 && z == 0
        my $val = 
             $self->potential($x,   $y-1, $z) +
            ($self->raw($x,   $y,   $z) -
             $field_y) / 2.0
        ;
        $self->point($x, $y, $z, $is_electrode, $val);
    }
    elsif($x != 0) { # y == 0 && z == 0
        my $val = 
             $self->potential($x-1, $y,   $z) +
            ($self->raw($x,   $y,   $z) -
             $field_x) / 2.0
        ;
        $self->point($x, $y, $z, $is_electrode, $val);
    }
    else { # x == 0 && y == 0 && z == 0
        $self->point($x, $y, $z, $is_electrode, 0);
    }

    # print "DEBUG:point=", $self->potential($x, $y, $z), "\n";
}


sub _inside_cylindrical_real
{
    my($self, $x, $r) = @_;

    my $yes = (
        ($x >= 0.0) ? ($x <= $self->{nx}-1) :
        $self->mirror_x() ? (-$x <= $self->{nx}-1) :
        0
    ) && ($r <= $self->{ny} - 1);
    return $yes;
}


sub check
{
    my($self, %params) = @_;

    return 0 if defined($params{mode}) && !$self->check_mode($params{mode});
    return 0 if defined($params{symmetry}) &&
                !$self->check_symmetry($params{symmetry});
    return 0 if defined($params{max_voltage}) &&
                !$self->check_max_voltage($params{max_voltage});

    return 0 if defined($params{field_type}) &&
                !$self->check_field_type($params{field_type});

    return 0 if defined($params{ng}) && !$self->check_ng($params{ng});

    return 0 if defined($params{nx}) && !$self->check_nx($params{nx});
    return 0 if defined($params{ny}) && !$self->check_ny($params{ny});
    return 0 if defined($params{nz}) && !$self->check_nz($params{nz});
    return 0 if defined($params{nx}) && defined($params{ny}) &&
        !$self->check_size($params{nx}, $params{ny}, $params{nz});

    return 0 if defined($params{dx_mm}) &&
                !$self->check_dx_mm($params{check_dx_mm});
    return 0 if defined($params{dy_mm}) &&
                !$self->check_dy_mm($params{check_dy_mm});
    return 0 if defined($params{dz_mm}) &&
                !$self->check_dz_mm($params{check_dz_mm});


    # aliases
    if(defined($params{mirror})) {
        croak "mirror and mirror_x named parameters cannot coexist."
            if defined($params{mirror_x});
        croak "mirror and mirror_y named parameters cannot coexist."
            if defined($params{mirror_y});
        croak "mirror and mirror_z named parameters cannot coexist."
            if defined($params{mirror_z});
        ($params{mirror_x}, $params{mirror_y}, $params{mirror_z}) =
            &_parse_mirror($params{mirror});
    }

    if(&_def($params{symmetry}) eq 'cylindrical' &&
       defined($params{mirror_y}) && !$params{mirror_y})
    {
        $self->{error} = "y mirroring must be enabled under cylindrical symmetry.";
        return 0;
    }

    if(&_def($params{symmetry}) eq 'cylindrical' &&
       defined($params{nz}) && $params{nz} != 1)
    {
        $self->{error} = "nz ($params{nz}) must be 1 under cylindrical symmetry.";
        return 0;
    }

    if($params{mirror_z} &&
       defined($params{nz}) && $params{nz} == 1)
    {
        $self->{error} = "nz ($params{nz}) cannot be 1 under z mirroring.";
        return 0;
    }

    return 1;
}

sub check_field_type
{
    my($self, $field_type) = @_;
    unless($field_type =~ /^(?:electrostatic|magnetic)$/s) {
        $self->{error} = "Field type ($field_type) must be 'electrostatic' or 'magnetic'.";
        return 0;
    }
    return 1;
}

sub check_max_voltage
{
    my($self, $voltage) = @_;
    unless($voltage > 0) { # Q:ok?
        $self->{error} = "Max voltage ($voltage) is out of range.";
        return 0;
    }
    return 1;
}

sub check_mirror
{
    my($self, $mirror) = @_;
    unless($mirror =~ /^x?y?z?$/s) {
        $self->{error} = "Mirror string ($mirror) invalid.";
        return 0;
    }
    return 1;
}

sub check_mode
{
    my($self, $mode) = @_;
    unless($mode == -1 || $mode == -2) {
        $self->{error} = "Mode ($mode) is out of range.";
        return 0;
    }
    return 1;
}

sub check_ng
{
    my($self, $ng) = @_;
    unless($ng >= 0) {
        $self->{error} = "Magnetic scaling factor ng ($ng) must be no less than 0.";
        return 0;
    }
    return 1;
}

sub check_nx
{
    my($self, $nx) = @_;
    unless($nx >= 3) {
        $self->{error} = "nx value ($nx) must be no less than 3."; return 0;
    }
    unless($nx <= 90000) {
        $self->{error} = "nx value ($nx) must be no greater than 90000."; return 0;
    }
    return 1;
}

sub check_ny
{
    my($self, $ny) = @_;
    unless($ny >= 3) {
        $self->{error} = "ny value ($ny) must be no less than 3."; return 0;
    }
    unless($ny <= 90000) {
        $self->{error} = "ny value ($ny) must be no greater than 90000."; return 0;
    }
    return 1;
}

sub check_nz
{
    my($self, $nz) = @_;
    unless($nz >= 1) {
        $self->{error} = "nz value ($nz) must be no less than 1."; return 0;
    }
    unless($nz <= 90000) {
        $self->{error} = "nz value ($nz) must be no greater than 90000."; return 0;
    }
    return 1;
}

sub check_size
{
    my($self, $nx, $ny, $nz) = @_;

    $nz = 1 if !defined $nz;

    return 0 if !$self->check_nx($nx);
    return 0 if !$self->check_ny($ny);
    return 0 if !$self->check_nz($nz);

    if($nx * $ny * $nz > 200000000) {
        $self->{error} = "($nx,$ny,$nz) exceeds 200 million points.";
        return 0;
    }
    return 1;
}

sub check_symmetry
{
    my($self, $symmetry) = @_;
    unless($symmetry =~ /^(?:planar|cylindrical)$/s) {
        $self->{error} = "Symmetry ($symmetry) must be 'planar' or 'cylindrical'.";
        return 0;
    }
    return 1;
}

sub check_dx_mm
{
    my ($self, $val) = @_;
    unless ($val >= 1e-6) {
        $self->{error} = "dx_mm value ($val) must be no less than 1e-6."; return 0;
    }
    unless ($val <= 900) {
        $self->{error} = "dx_mm value ($val) must be no greater than 900."; return 0;
    }
    return 1;
}

sub check_dy_mm
{
    my ($self, $val) = @_;
    unless ($val >= 1e-6) {
        $self->{error} = "dy_mm value ($val) must be no less than 1e-6."; return 0;
    }
    unless ($val <= 900) {
        $self->{error} = "dy_mm value ($val) must be no greater than 900."; return 0;
    }
    return 1;
}

sub check_dz_mm
{
    my ($self, $val) = @_;
    unless ($val >= 1e-6) {
        $self->{error} = "dz_mm value ($val) must be no less than 1e-6."; return 0;
    }
    unless ($val <= 900) {
        $self->{error} = "dz_mm value ($val) must be no greater than 900."; return 0;
    }
    return 1;
}

sub error
{
    my($self) = @_;
    return $self->{error};
}

1


