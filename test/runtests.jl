#!/usr/bin/env julia

using WCS
using Base.Test

wcs = WCSTransform(2;
                   alt     = 'B',
                   cdelt   = [-0.066667, 0.066667],
                   colnum  = 2,
                   ctype   = ["RA---AIR", "DEC--AIR"],
                   crpix   = [-234.75, 8.3393],
                   crval   = [0.0, -90.0],
                   obsgeo  = [1.0, 2.0, 3.0],
                   pc      = [1.0 0.0; 0.0 1.0],
                   pv      = [(2, 1, 45.0)],
                   velangl = 3,
                   wcsname = "WCSLIB.jl")

pixcoords = [0.0 24.0 45.0;  # x coords
             0.0 38.0 98.0]  # y coords

worldcoords = pix_to_world(wcs, pixcoords)

expected_world = [267.96547027 276.53931377 287.77080792;
                  -73.73660749 -71.97412809 -69.67813884]

@test maximum(abs(worldcoords .- expected_world)) < 5e-9
pixcoords_out = world_to_pix(wcs, worldcoords)
@test maximum(abs(pixcoords_out .- pixcoords)) < 1e-9

# Test Array{Float64, 1} methods of above
worldcoords = pix_to_world(wcs, pixcoords[:, 1])
@test maximum(abs(worldcoords .- expected_world[:, 1])) < 5e-9
pixcoords_out = world_to_pix(wcs, worldcoords)
@test maximum(abs(pixcoords_out .- pixcoords[:, 1])) < 1e-9

# Test retrieving attributes
@test wcs[:ctype] == ["RA---AIR", "DEC--AIR"]
@test wcs[:dateavg] == ""
@test wcs[:alt] == 'B'
@test wcs[:cdelt] == [-0.066667, 0.066667]
@test wcs[:cd] == [0.0 0.0; 0.0 0.0]
@test wcs[:obsgeo] == (1.0, 2.0, 3.0)

header = "SIMPLE  =                    T / file does conform to FITS standard             BITPIX  =                  -64 / number of bits per data pixel                  NAXIS   =                    2 / number of data axes                            NAXIS1  =                 3636 / length of data axis 1                          NAXIS2  =                 1939 / length of data axis 2                          EXTEND  =                    T / FITS dataset may contain extensions            COMMENT   FITS (Flexible Image Transport System) format is defined in 'AstronomyCOMMENT   and Astrophysics', volume 376, page 359; bibcode: 2001A&A...376..359H WCSAXES =                    2 / Number of coordinate axes                      CRPIX1  =               1818.0 / Pixel coordinate of reference point            CRPIX2  =                969.5 / Pixel coordinate of reference point            CDELT1  =             -0.00825 / [deg] Coordinate increment at reference point  CDELT2  =              0.00825 / [deg] Coordinate increment at reference point  CUNIT1  = 'deg'                / Units of coordinate increment and value        CUNIT2  = 'deg'                / Units of coordinate increment and value        CTYPE1  = 'RA---CEA'           / Right ascension, cylindrical equal area projectCTYPE2  = 'DEC--CEA'           / Declination, cylindrical equal area projection CRVAL1  =            3.575E+02 / [deg] Coordinate value at reference point      CRVAL2  =            0.000E+00 / [deg] Coordinate value at reference point      PV2_1   =                  1.0 / CEA projection parameter                       LONPOLE =                  0.0 / [deg] Native longitude of celestial pole       LATPOLE =                 90.0 / [deg] Native latitude of celestial pole        RADESYS = 'ICRS'               / Equatorial coordinate system                                                                                                   COMMENT  WCS header keyrecords produced by WCSLIB 5.9                           "

ws = WCS.from_header(header)
@test length(ws) == 1
@test eltype(ws) === WCSTransform
w = ws[1]

@test w.naxis == 2

# Check that `to_header` succeeds and has the right number
# of records. (Checking exact equality of input and output
# strings is too demanding, as the exact formatting differs
# between minor WCSLIB versions. For example,
# `0.0E+00` vs `0.000E+00`.)
header_out = WCS.to_header(w)
@test length(header_out) == 17 * 80

# Test that wcslib_version works at all
@test WCS.wcslib_version() > v"5.0"

# Test propagating errors from wcslib.
# TODO: replace this with a public WCS routine that throws an error.
@test_throws ErrorException WCS.assert_ok(Cint(1))
