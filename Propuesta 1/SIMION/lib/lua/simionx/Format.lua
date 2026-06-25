-- simionx.Format
-- This module is documented in the SIMION supplemental documentation.
-- version: 20071023
-- (c) 2007 Scientific Instrument Services, Inc. (SIMION 8.0 License)

local format = string.format

local M = {}

function M.scientific_notation(value, error)
  local s
  if error == 0 then
    s = format("%0.15e", value)
  else
    if value == 0 then value = error / 1000 end

    local sv0 = format("%e", value)
    local m1 = assert(sv0:match("e([+-]%d+)"))
    local value_exponent = tonumber(m1)

    local se = format("%0.1e", error)
    local m2 = assert(se:match("e([+-]%d+)"))
    local error_exponent = tonumber(m2)

    local digits = value_exponent - error_exponent + 1

    local sv
    if digits >= 0 then
      sv = format(format("%%0.%de", digits), value)
    elseif digits == -1 then
      local m1 = assert(sv0:match("([0-9])"))
      sv = ((value > 0 and 1 or -1) ..
           format("e%+03d", value_exponent+1))
    else
      sv = "0e" .. m2
    end
    -- recompute value_exponent
    local m1 = assert(sv:match("e([+-]%d+)"))
    local value_exponent_new = tonumber(m1)
    -- print(value_exponent ,error_exponent, value_exponent_new)
    local efmt = format("%%0.%df",
                 math.max(0, value_exponent_new - error_exponent + 1))
    local se = format(efmt, error * 10^(-value_exponent_new)) ..
               format("%e", 10^value_exponent_new):gsub("^[^eE]*", "")
    s = format("%s +/- %s", sv, se)
  end
  s = s:gsub("([eE][+-]%d+)", "%1_")
  s = s:gsub("([eE][+-])0*(%d+)_", "%1%2")
  s = s:gsub("_", "")
  return s
end

return M

--[==[
=pod

=head1 NAME

simionx.Format - String format utility functions

=head1 SYNOPSIS

  local FMT = require "simionx.Format"
  
  local s = FMT.scientific_notation(123.456, 0.1)
  assert(s == "1.2346e+2 +/- 0.0010e+2")

=head1 DESCRIPTION

This module provides functions for string formatting, such as formatting
a number in scientific notation with error bounds.

=head1 INTERFACE

=head2 Functions

=head3 scientific_notation

  s = FMT.scientific_notation(value, error)

Format number C<value> with error C<error> in scientific notation with
error bound (e.g. "2.27810e-05 +/- 2.2e-09").  Note: this is similar
to the approach taken in the Number::WithError Perl module.

=head1 SOURCE

(c) 2007 Scientific Instrument Services, Inc.
Licensed under the terms of SIMION 8.0.  www.simion.com.
D.Manura-2007.

=cut
--]==]
