/**
 * @mainpage
 *
 * This is the C++ version of the SIMION SL Libraies.
 * It provides libraries for manipulating SIMION potential array (PA/PA?)
 * files.
 *
 * <a href="namespacesimion.html">simion namespace members</a>
 *
 * Changes / COMPATIBILITY
 *
 * The PA class was extended and changed significantly between the SL
 * Toolkit 1.0 and 1.2.  Refer to the SL Toolkit Change Log for
 * details.
 *
 * Changes:
 *   2010-01-25
 *     Add support for mode -2 PA files (SIMION 8.1 anisotropic scaling
 *        x_mm_per_gu/y_mm_per_gu/z_mm_per_gu).
 *     Remove old FIX comments.
 *     Fix g++4 compilation errors.
 *   2011-08-04
 *     Add 64-bit support (for >=16 GB SIMION 8.1.0 arrays).
 *   2011-08-11
 *     Renamed x_mm_per_gu/y_mm_per_gu/z_mm_per_gu -> dx_mm/dy_mm/dz_mm
 *   2011-08-15
 *     ng changed from int to double (SIMION 8.1 compatibility)
 *     only include first 17 bits of ng in mirror (SIMION 8.1 compatibility)
 *
 * @author David Manura (c) 2003-2013 Scientific Instrument Services, Inc.
 * Licensed under the terms of SIMION 8.0/8.1 or the SIMION SL Toolkit.
 * Created 2003-11.
 */

/**
 * @file pa.h
 * Header file for SIMION potential array class.
 *
 * This class provides methods for reading, writing, and
 * manipulating SIMION potential array (PA/PA?) files.
 *
 * Refer to Appendix Section F.5 of the SIMION 8.0 manual
 * (or page D-5 of the SIMION 7.0 manual) for info on the
 * %PA file format.
 *
 * You may want to disable assertions (via the macro NDEBUG)
 * if speed is critical.
 *
 * v1.0.0.20130514
 *
 * @author (c) 2003-2013 Scientific Instrument Services, Inc.  David Manura.
 * Licensed under the terms of SIMION 8.0/8.1 or the SIMION SL Toolkit.
 * $Revision$ $Date$ Created 2003-11.
 *
 */


#ifndef SIMIONSL_PA_H
#define SIMIONSL_PA_H

#include "util.h"

#include <iostream>
#include <vector>
#include <string>

/**
 * The SIMION namespace for the SIMION SL Toolkit.
 *
 * This namespace holds all SIMION SL Toolkit classes and members.
 * Example:
 *
 *     @code
 *     #include <simion/pa.h>
 *     #include <iostream>
 *     using namespace simion;
 *     using namespace std;
 *     int main() {
 *         PA pa();
 *         cout << pa.header_patxt() << endl;
 *         return 0;
 *     }
 *     @endcode
 */

namespace simion
{

/**
 * symmetry constants.
 */
enum symmetry_t
{
    /// cylindrical symmetry
    CYLINDRICAL =    0,
    /// planar symmetry
    PLANAR =         1
};

/**
 * potential array field types.
 */
enum field_t
{
    /// electrostatic
    ELECTROSTATIC = 0,
    /// magnetic
    MAGNETIC = 1
};

/**
 * Bits definitions for the "mirror" field in the header of a PA file.
 * @see PAHeader.
 */
enum mirror_t
{
    /// array mirrored in x
    MIRROR_X =       1,
    /// array mirrored in y
    MIRROR_Y =       2,
    /// array mirrored in z
    MIRROR_Z =       4,
    /// is magnetic potential array (else assumed electrostatic array)
    MAGNETIC_PA =    8
};


class PA;
class PAArgs;
class PAHeader;
class PAFormat;
class PAPointInfo;
class PATextHeader;
class PATextHandler;
class Vector3R;
class Task; // extern
class PATextImpl_;

/**
 * Class representing a three-dimensional vector of real components
 * (x, y, z).
 */
class Vector3R
{
public:
    /** Constructor. */
    Vector3R(double x=0.0, double y=0.0, double z=0.0);

    /** Set x, y, z components simultaneously. */
    void set(double x, double y, double z);

    /** Get x component. */
    double x() const;
    /** Set x component. */
    void x(double val);

    /** Get y component. */
    double y() const;
    /** Set y component. */
    void y(double val);

    /** Get z omponent. */
    double z() const;
    /** Set z component. */
    void z(double val);

private:
    double x_, y_, z_;
};

/**
 * Constainer class representing a single data point in a %PA.
 * This is used as a return value in certain PA methods
 * (e.g. point).
 */
class PAPoint
{
public:
    /** Whether point is an electrode. */
    bool electrode;
    /** Potential of point (volts or mags). */
    double potential;

    /**
      * Constructor.
      * @param electrode_ whether point is an electrode.
      * @param potential_ potential in volts or mags.
      */
    PAPoint(bool electrode_, double potential_) :
        electrode(electrode_), potential(potential_) { }

};

/**
 * Base class for custom PA memory allocators.
 * This is typically only used for advanced applications
 * needing to manage their own memory.
 * Functions have the same semantics as C malloc and free
 * functions.
 */
class PAAllocator
{
public:
    /** similar to C malloc() */
    virtual void * malloc(size_t nbytes) = 0;
    /** similar to C free() */
    virtual void free(void * data) = 0;
};


//IMPROVE: support pasharp?

/**
 * Container class for a set of potential array attributes.
 * This allows any subset of the attributes to be passed at once into
 * a given function, somewhat like named parameters in other languages.
 * For example,
 *
 *   @code
 *   PA pa(PAArgs().nx(10).ny(20).symmetry(CYLINDRICAL));
 *   @endcode
 *
 * See the PA class for details on the meaning of these attributes.
 * Additional attributes are
 *
 *   - fast_adjustable - whether array is fast adjustable
 *   - enable_points - whether to load/save point data (in addition to header)
 *
 * Each attribute has three methods:
 *
 *   - get value
 *   - get whether value is defined
 *   - set value
 *
 * The typical usage by the caller is
 *
 *   @code
 *   args.nx(100);
 *   @endcode
 *
 * The typical usage by the receiver is
 *
 *   @code
 *   if(args.nx_defined()) cout << args.nx(); // do something
 *   @endcode
 *
 * Note that this class performs no checking on values.  Checking is
 * the responsibility of the PA class.
 *
 * @see PA
 */
class PAArgs
{
public:
    /** Identifiers for arguments. */
    enum arg_t {
        A_file            = (1 << 0),
        A_mode            = (1 << 1),
        A_max_voltage     = (1 << 2),
        A_nx              = (1 << 3),
        A_ny              = (1 << 4),
        A_nz              = (1 << 5),
        A_mirror_x        = (1 << 6),
        A_mirror_y        = (1 << 7),
        A_mirror_z        = (1 << 8),
        A_field_type      = (1 << 9),
        A_symmetry        = (1 << 10),
        A_ng              = (1 << 11),
        A_dx_mm           = (1 << 12),
        A_dy_mm           = (1 << 13),
        A_dz_mm           = (1 << 14),
        A_fast_adjustable = (1 << 15),
        A_enable_points   = (1 << 16),
        A_allocator       = (1 << 17)
    };

    /***
     * Constructor.
     */
    PAArgs() :
        file_            (),
        mode_            (-1),
        max_voltage_     (100000),
        nx_              (100),
        ny_              (100),
        nz_              (1),
        mirror_x_        (false),
        mirror_y_        (false),
        mirror_z_        (false),
        field_type_      (ELECTROSTATIC),
        symmetry_        (PLANAR),
        ng_              (100.0),
        dx_mm_           (1.0),
        dy_mm_           (1.0),
        dz_mm_           (1.0),
        fast_adjustable_ (false),
        enable_points_   (true),
        allocator_       (NULL),
        valid_           (0) /// flags marking valid attributes (OR of arg_t)
    { }

    // Each attribute is given a set of three methods
    // defined by the below macro.

#   ifndef DOXYGEN_SHOULD_SKIP_THIS
#   define SL_MAKE_METHODS(name, type) \
        /** Get name attribute. */ \
        type name() const { return name ## _; } \
        /** Get whether name attribute defined. */ \
        bool name ## _defined() const { return is_set_(A_ ## name); } \
        /** Set name attribute. */ \
        PAArgs& name(type val) { name ## _ = val; set_(A_ ## name); return *this; }
#   endif

    SL_MAKE_METHODS(file,            std::string)
    SL_MAKE_METHODS(mode,            int)
    SL_MAKE_METHODS(max_voltage,     double)
    SL_MAKE_METHODS(nx,              int)
    SL_MAKE_METHODS(ny,              int)
    SL_MAKE_METHODS(nz,              int)
    SL_MAKE_METHODS(mirror_x,        bool)
    SL_MAKE_METHODS(mirror_y,        bool)
    SL_MAKE_METHODS(mirror_z,        bool)
    SL_MAKE_METHODS(field_type,      field_t)
    SL_MAKE_METHODS(symmetry,        symmetry_t)
    SL_MAKE_METHODS(ng,              double)
    SL_MAKE_METHODS(dx_mm,           double)
    SL_MAKE_METHODS(dy_mm,           double)
    SL_MAKE_METHODS(dz_mm,           double)
    SL_MAKE_METHODS(fast_adjustable, bool)
    SL_MAKE_METHODS(enable_points,   bool)
    SL_MAKE_METHODS(allocator,       PAAllocator*)

    /** Gets and OR-ed bit field of arguments defined. */
    int defined();

#   undef SL_MAKE_METHODS

private:

    std::string file_;
    int         mode_;
    double      max_voltage_;
    int         nx_;
    int         ny_;
    int         nz_;
    bool        mirror_x_;
    bool        mirror_y_;
    bool        mirror_z_;
    field_t     field_type_;
    symmetry_t  symmetry_;
    double      ng_;
    double      dx_mm_;
    double      dy_mm_;
    double      dz_mm_;
    bool        fast_adjustable_;
    bool        enable_points_;
    PAAllocator * allocator_;

    int         valid_;  // bitwise OR of arg_t flags

    void set_(arg_t val);
    bool is_set_(arg_t val) const;
};


//IMPROVE:implement setters too?
/**
 * Class that implements the header section of a %PA file format.
 *
 * Note: This class is normally not used by SL Toolkit users.  The
 * class provides a low-level interface to the PA file format,
 * whereas the PA class provides a higher level interface to %PA files.
 *
 * The binary representation of this class is designed to be writen
 * to the header section of the PA file.
 *
 * Refer to Appendix Section F.5 of the SIMION 8.0 Manual
 * (or page D-5 of the SIMION 7.0 manual) for info on the
 * %PA file format.
 */
class PAHeader
{
public:
    /** Mode: -1 (SIMION 7.0/8.0), -2 (8.1 anisotropic)  */
    int mode_;

    /** Symmetry (PLANAR or CYLINDRICAL) */
    int symmetry_;

    /**  max voltage limit */
    double max_voltage_;

    /** number of grid points in x direction */
    int nx_;

    /** number of grid points in y direction */
    int ny_;

    /** number of grid points in z direction */
    int nz_;

    /**
      * first three lowest bits are the x, y, and z
      * mirroring respectively.  Remaining bits are
      * the ng magnetic scaling factor.
      */
    int mirror_;

    /**
     * Grid unit size (mm) in x direction.
     * Used for mode=-2 only.
     */
    double dx_mm_;

    /**
     * Grid unit size (mm) in y direction.
     * Used for mode=-2 only.
     */
    double dy_mm_;

    /**
     * Grid unit size (mm) in z direction.
     * Used for mode=-2 only.
     */
    double dz_mm_;

    /**
     * Constructor.
     */
    PAHeader() :
        mode_        (-1),
        symmetry_    (PLANAR),
        max_voltage_ (100000.0),
        nx_          (100),
        ny_          (100),
        nz_          (1),
        mirror_      (0 + (100<<4)),
        dx_mm_       (1.0),
        dy_mm_       (1.0),
        dz_mm_       (1.0)
    { }

    /**
     * Constructor.
     * @param mode mode: -1 (SIMION 7.1/8.0), -2 (SIMION 8.1 anisotropic scaling)
     * @param field_type field type (ELECTROSTATIC or MAGNETIC)
     * @param symmetry symmetry (PLANAR or CYLINDRICAL)
     * @param max_voltage max voltage limit
     * @param nx number of grid points in x direction
     * @param ny number of grid points in y direction
     * @param nz number of grid points in z direction
     * @param mirror_x whether x mirroring is enabled
     * @param mirror_y whether y mirroring is enabled
     * @param mirror_z whether z mirroring is enabled
     * @param ng magnetic scaling factor
     * @param dx_mm grid size in X direction (for mode -2 only)
     * @param dy_mm grid size in Y direction (for mode -2 only)
     * @param dz_mm grid size in Z direction (for mode -2 only)
     */
    PAHeader(
        int        mode,
        field_t    field_type,
        symmetry_t symmetry,
        double     max_voltage,
        int        nx,
        int        ny,
        int        nz,
        bool       mirror_x,
        bool       mirror_y,
        bool       mirror_z,
        double     ng,
        double     dx_mm = 1.0,
        double     dy_mm = 1.0,
        double     dz_mm = 1.0
    );

    /** Get whether x mirroring is enabled. */
    bool mirror_x() const;
    /** Get whether y mirroring is enabled. */
    bool mirror_y() const;
    /** Get whether z mirroring is enabled. */
    bool mirror_z() const;

    /** Get whether field type identifier. */
    field_t field_type() const;

    /** Get ng magnetic scaling factor. */
    double ng() const;

    /** Get symmetry identifier. */
    symmetry_t symmetry() const;

    /**
     * Returns number of points in array.
     * That is, nx * ny * nz.
     */
    ptrdiff_t num_points() const;
};

/**
 * header used by the PATXT format
 */
class PATextHeader : public PAArgs
{
public:
    /** identifiers for data columns */
    enum point_column_t
    {
        PI_X            = (1<<0),
        PI_Y            = (1<<1),
        PI_Z            = (1<<2),
        PI_IS_ELECTRODE = (1<<3),
        PI_POTENTIAL    = (1<<4),
        PI_RAW_VALUE    = (1<<5),
        PI_FIELD_X      = (1<<6),
        PI_FIELD_Y      = (1<<7),
        PI_FIELD_Z      = (1<<8),

        PI_FIELD        = PI_FIELD_X | PI_FIELD_Y | PI_FIELD_Z,
        PI_XYZ          = PI_X | PI_Y | PI_Z
    };

    /**
     * Constructor.
     */
    PATextHeader() : columns_enabled_(0) { }

    /**
     * Gets whether data point column is enabled.
     */
    bool is_column_enabled(point_column_t t) const;

    /**
     * Set data point column at given index.
     */
    void enable_column(int idx, point_column_t t);

    /**
     * Get set of enabled columns (as OR'ed bitfield).
     */
    int enabled_columns() const;

    /**
     * Get value at given data point column.
     */
    point_column_t column(int idx) const;

    /**
     * Get number of data point columns.
     */
    int column_count() const;

private:
    int columns_enabled_;
    std::vector<point_column_t> columns_;
};

/**
 * Container class for options passed to PA.save().
 *
 * Like PAArgs, this simulated named parameter passing.
 */
class PAFormat
{
public:
    /** file formatting */
    enum format_t {
        /// normal SIMION binary format
        BINARY,
        /// ASCII PATXT format
        ASCII
    };

    /** what the data values represent */
    enum values_t {
        /// scalar potentials
        POTENTIAL,
        /// field vectors
        FIELD
    };

    /**
     * Constructor.
     *  format_t file formatting
     *  double sampling interval
     *  enable_header whether the header is enabled (ASCII format only)
     *  enable_data whether the data points are enabled (ASCII format only)
     *  enable_coords whether the (x,y,z) coordinates are enabled for
     *    data points (only for ASCII format with enable_data set)
     *  values_t what the data points contain (ASCII format only.
     *    POTENTIAL is assumed for binary format)
     */
    PAFormat(
        format_t       format = BINARY,
        double         dx = 1,
        bool           enable_header = true,
        bool           enable_data = true,
        bool           enable_coords = true,
        values_t       values = POTENTIAL)
    :
        format_        (format),
        dx_            (dx),
        enable_header_ (enable_header),
        enable_data_   (enable_data),
        enable_coords_ (enable_coords),
        values_        (values)
    { }

#   ifndef DOXYGEN_SHOULD_SKIP_THIS
#   define SL_MAKE_METHODS(name, type) \
        /** Get name. */ \
        type name() const { return name ## _; } \
        /** Set name. */ \
        PAFormat& name(type val) { name ## _ = val; return *this;}
#   endif

    SL_MAKE_METHODS(format, format_t)
    SL_MAKE_METHODS(dx, double)
    SL_MAKE_METHODS(enable_header, bool)
    SL_MAKE_METHODS(enable_data, bool)
    SL_MAKE_METHODS(enable_coords, bool)
    SL_MAKE_METHODS(values, values_t)

#   undef SL_MAKE_METHODS

private:
    format_t           format_;
    double             dx_;
    bool               enable_header_;
    bool               enable_data_;
    bool               enable_coords_;
    values_t           values_;
};


/**
 * Container class used by PATextHandler to store information
 * about a single data point mentioned in a PATXT file.
 *
 * NOTE: This class is typically not used directly be SL Toolkit users.
 * See the PA class instead.
 */
class PAPointInfo
{
private:
    int    x_;
    int    y_;
    int    z_;
    bool   is_electrode_;
    double potential_;
    double raw_value_;
    double field_x_;
    double field_y_;
    double field_z_;

    int enabled_; // ORed point_column_t
public:
    PAPointInfo() :
        x_            (0),
        y_            (0),
        z_            (0),
        is_electrode_ (false),
        potential_    (0.0),
        raw_value_    (0.0),
        field_x_      (0.0),
        field_y_      (0.0),
        field_z_      (0.0),
        enabled_      (0)
    { }

#   ifndef DOXYGEN_SHOULD_SKIP_THIS
#   define SL_MAKE_METHODS(name, type) \
        /** Get name. */ \
        type name() const { return name ## _; } \
        /** Set name. */ \
        void name(type val) { name ## _ = val; }
#   endif

    SL_MAKE_METHODS(x,            int)
    SL_MAKE_METHODS(y,            int)
    SL_MAKE_METHODS(z,            int)
    SL_MAKE_METHODS(is_electrode, bool)
    SL_MAKE_METHODS(potential,    double)
    SL_MAKE_METHODS(raw_value,    double)
    SL_MAKE_METHODS(field_x,      double)
    SL_MAKE_METHODS(field_y,      double)
    SL_MAKE_METHODS(field_z,      double)
    SL_MAKE_METHODS(enabled,      int)

#   undef SL_MAKE_METHODS

    /**
     * Get string representation of object.
     */
    std::string string() const;
};

/**
 * Abstract base class for call-back handlers used by the by the PATXT
 * processor.
 *
 * Note: This class is normally not used by SL Toolkit users.
 * The PA class uses this internally.
 */
class PATextHandler
{
public:
    /**
     * Handler PATXT header.
     * This is called once at the start of processing.
     */
    virtual void process_header(const PATextHeader& header) = 0;

    /**
     * Handle point.
     * This is called for each point in lexographic order.
     */
    virtual void process_point(const PAPointInfo& info) = 0;
};



/**
 * SIMION Potential array class.
 *
 * This C++ class provides functionality for reading/writing SIMION
 * potential array files (PA/PA?).
 *
 * This now support an ASCII text format for PAs.  This text format
 * may be either in the DOS or UNIX text format.
 *
 * SYNOPSIS
 * @code
 * <div style="background-color:#e0e0e0"><pre>
 * #include <simion/pa.h>
 * //#include <simion/pa.cpp>
 *
 * int main()
 * {
 *     // example reading
 *     PA pa;
 *     pa.load("buncher.pa#");
 *     cout << pa.header_string() << endl;
 *
 *     // example writing
 *     PA pa2(PAArgs().nx(100).ny(20).symmetry(CYLINDRICAL));
 *     int x,y,z;
 *     z = 0;
 *     for(y=0; y < pa2.ny(); y++) {
 *     for(x=0; x < pa2.nx(); x++) {
 *         bool inside = (x+y) < 10;
 *         if(inside) pa2.point(x, y, z, true, 5); // electrode 5V
 *     }}
 *     pa2.save("cone.pa#");
 *
 *     // create a magnetic field from scratch
 *     PA pa3(PAArgs().nx(50).ny(50).field_type(MAGNETIC));
 *     z = 0;     
 *     for(y=0; y < pa3.ny(); y++) {
 *     for(x=0; x < pa3.nx(); x++) {
 *         double ex = x;
 *         double ey = y*y;
 *         double ez = 0;
 *         pa3.field(x, y, z, ex, ey, ez);
 *     }}
 *     pa3.save("mag1.pa");
 *
 *     return 0;
 * }
 * @endcode
 *
 * TERMINOLOGY
 *
 * A potential array consist of a set of (integer) grid
 * points within a 2D rectangle or 3D rectangular prism.
 * These points are denoted (xi, yi, zi) for xi in 0..nx-1,
 * yi in 0..ny-1, zi in 0..nz-1 (where nz=1 in the 2D case).
 *
 * All grid points are assigned a real potential and are marked as
 * either electrodes or non-electrodes.  Any real point (x, y, z) is
 * directly surrounded by at most four (2D) or eight (3D) grid points.
 * If all surrounding points are electrodes, the point is considered a
 * solid point (which can splat ions).  Electrode points that are not
 * solid points make up ideal grid (which allow ions to fly through).
 * Solids have finite width, while ideal grids have infinitesimal width.
 *
 * To reduce the number of computations, the grid is assigned
 * symmetry (cylindrical or planar) and mirroring (x, y, or z).  In
 * cylindrical symmetry (which only applies to 2D grids), the 2D grid
 * is revolved around the line x=0 to generate a 3D geometry.  A 2D
 * grid under planar symmetry is duplicated infinitely in the Z
 * direction.  A 3D grid (which can only have planar symmetry), is unchanged.
 * x mirroring equated point (x, y, z) to (-x, y, z), and the analogous is
 * true for the other dimensions.
 *
 * See Appendix Section F.5 of the SIMION 8.0 manual (or D-5 of the
 * SIMION 7.0 manual) for info on the
 * %PA file format.  See other sections on PAs for more general background.
 *
 */

class PA
{
public:
    // 64-bit detection
    #if defined(_M_X64) || defined(__x86_64__)
    static const bool MEMORY_64BIT = true;
    static const ptrdiff_t MAX_POINTS = ptrdiff_t(192) * 1024 * 1024 * 1024 / 16; // about 192 GB
    #else
    /** Whether this is a 64-bit array. */
    static const bool MEMORY_64BIT = false;
    /** Maximum number of points in any array. */
    static const ptrdiff_t MAX_POINTS = 200000000;
    #endif

    /**
     * @name Construction and Serialization
     * @{
     */

    /**
     * Constructs a new, empty potential array.
     *
     * By default,
     *   - mode            = -1,
     *   - symmetry        = PLANAR,
     *   - max_voltage     = 100000,
     *   - nx              = 3,
     *   - ny              = 3,
     *   - nz              = 1,
     *   - ng              = 100,
     *   - mirror_x        = false,
     *   - mirror_y        = false,
     *   - mirror_z        = false,
     *   - fast_adjustable = false,
     *   - enable_points   = true,
     *   - dx_mm           = 1.0,
     *   - dy_mm           = 1.0,
     *   - dz_mm           = 1.0
     */
    PA();

    /**
     * Constructs a new potential array from the given arguments.
     * The default arguments are the same as in PA().
     *
     * Example:
     *
     *    @code
     *    PA pa(PAArgs().nx(10).ny(20).nz(30).symmetry(CYLINDRICAL));
     *    @endcode
     */
    PA(const PAArgs& args);

    /**
     * Destructor.
     * All used memory is freed.
     */
    virtual ~PA();

    /**
     * Returns a string containing PATXT-formatted header
     * for the current array.
     *
     * For example, for SIMION's QUAD.PA# file, the result is as such: 
     *
     *   @verbatim
     *   begin_header
     *       mode -1
     *       symmetry planar
     *       max_voltage 20000
     *       nx 77
     *       ny 39
     *       nz 1
     *       mirror_x 0
     *       mirror_y 1
     *       mirror_z 0
     *       field_type electrostatic
     *       ng 100
     *       fast_adjustable 1
     *   end_header
     *   @endverbatim
     *
     * This method is also very useful for debugging to quickly display
     * the information on a given potential array. 
     *
     * @return string
     */
    std::string header_string() const;

    /**
     * Sets the task object for this PA.
     * This provides an optional features.  The task object, if present,
     * is used to provide feedback as the
     * percent completion of a long running task (e.g. loading/saving)
     * and to allow the task to be terminated prematurely.
     *
     * @param status pointer to task object (may be NULL to disable).
     */
    void set_status(Task* status);

    /**
     * Load potential array from file.
     * Throws string on error.
     *
     * @param path file path
     */
    void load(const std::string& path);

    /**
     * Load potential array from an input stream.
     * Throws string on error.
     *
     * @param is input stream
     */
    void load(std::istream& is);

    /**
     * Saves the potential array to a file.
     * Throws string on error.
     *
     * To save to a binary file, do something like
     *
     *   @code
     *   pa.save("myfile.pa#");
     *   @endcode
     *
     * To save to an ASCII formatted file, or for additional options, do
     * something like
     *
     *  @code
     *  pa.save("myfile.pa#",
     *      PAFormat().format(PAFormat::ASCII).enable_coords(false));
     *  @endcode
     *
     * @param path file path
     * @param opt Format options (optional).  If omitted, the binary
     *        format is used.
     */
    void save(const std::string& path, const PAFormat& opt = PAFormat());

    /**
     * Writes the potential array to an output stream.
     * Throws string on error.
     *
     * @param os output stream
     * @param opt Format options (optional).  If omitted, the binary
     *        format is used.
     */
    void save(std::ostream& os, const PAFormat& opt = PAFormat());


    /// @}

    /**
     * @name Attribute Getters/Setters
     * @{
     */

    /**
     * Gets whether data points are enabled.
     *
     * The default is for points to be enabled, but if you only need
     * to manipulate header information, you can conserve memory by
     * disabling data points, in which case only the header
     * information (not the data points) are loaded from and saved to
     * a file.
     */
    bool enable_points() const;

    /**
     * Sets whether data points are enabled.
     */
    void enable_points(bool val);

    /**
     * Determines if array is fast adjustable.
     */
    bool fast_adjustable() const;

    /**
     * Sets whether array is fast adjustable.
     */
    void fast_adjustable(bool val);

    /**
     * Retrieves the field type (potential v.s. magnetic).
     *
     * @return field type
     */
    field_t field_type() const;

    /**
     * Sets the field type (potential v.s. magnetic).
     *
     * @param val field type
     */
    void field_type(field_t val);

    /**
     * Gets the max voltage value of the potential array.
     * The max voltage value affects the interpretation of
     * point potentials (see the point() function).
     * See Appendix Section F.5 of the SIMION 8.0 manual
     * (or p. D-6 of the SIMION 7.0 manual) for details on this
     * parameter.
     *
     * @return size
     */
    double max_voltage() const;

    /**
     * Sets the max voltage value of the potential array.
     * The max voltage value affects the interpretation of
     * point potentials (see the point() function).
     * SIMION typically sets the value slightly above the
     * maximum potential in the array due to floating point
     * rounding.
     * As of 2007-07-11, increasing this updates the array values.
     * Result is undefined if max_voltage is decreased below
     * the maximum potential in the array.
     * See Appendix Section F.5 of the SIMION 8.0 manual
     * (or p. D-6 of the SIMION 7.0 manual) for details on this
     * parameter.
     */
    void max_voltage(double val);

    /**
     * Gets whether array has X symmetry
     *
     * @return Boolean
     */
    bool mirror_x() const;

    /**
     * Sets whether array has X symmetry
     *
     * @param val has X symmetry
     */
    void mirror_x(bool val);

    /**
     * Gets whether array has Y symmetry.
     *
     * @return Boolean
     */
    bool mirror_y() const;

    /**
     * Sets whether array has Y symmetry.
     * This must be true for cylindrical arrays.
     *
     * @param val has Y symmetry
     */
    void mirror_y(bool val);

    /**
     * Gets whether array has Z symmetry.
     * This must be false for cylindrical and 2D planar arrays.
     *
     * @return Boolean
     */
    bool mirror_z() const;

    /**
     * Sets whether array has Z symmetry
     *
     * @param val has Z symmetry
     */
    void mirror_z(bool val);

    /**
     * Gets the mode number (format version).
     * -1 : SIMION 7.0/8.0
     * -2 : SIMION 8.1 (anisotropic scaling)
     * @return mode
     * This value may be more negative than the value provided
     * to mode(val) if the PA uses capabilities not supported in the
     * given mode.
     */
    int mode() const;

    /**
     * Sets the recommended mode number (format version).
     * This recommendation may be ignored if the PA uses
     * capabilities not supported in the given mode.
     * -1 : SIMION 7.0/8.0
     * -2 : SIMION 8.1 (anisotropic scaling)
     */
    void mode(int val);

    /**
     * Retrieves the "ng" scaling constant using in magnetic arrays.
     *
     * SIMION uses the ng constant to make magnetic potentials
     * correspond to magnetic field values.  Refer to Section 2.3.4
     * of the SIMION 8.0 manual (or page 2-10 in the SIMION 7.0 manual)
     * for details.
     *
     * @return ng
     */
    double ng() const;

    /**
     * Sets the "ng" scaling constant.
     *
     * SIMION uses the ng constant to make magnetic potentials
     * correspond to magnetic field values.  Refer to Section 2.3.4
     * of the SIMION 8.0 manual (or page 2-10 in the SIMION 7.0 manual)
     * for details.
     *
     * @param v new value
     */
    void ng(double v);

    /**
     * Returns number of points in array.
     * That is, nx * ny * nz.
     *
     * @return number of points
     */
    ptrdiff_t num_points() const;

    /**
     * Gets the number of voxels (2D or 3D pixels).
     *
     * Each voxel is surrounded by four (2D arrays) or eight (3D
     * arrays) grid points. For 2D arrays, this is (nx()-1) *
     * (ny()-1). For 3D arrays, this is (nx()-1) * (ny()-1) *
     * (nz()-1).
     */
    ptrdiff_t num_voxels() const;

    /**
     * Gets the array dimension in the x-direction (grid units)
     *
     * @return size
     */
    int nx() const;

    /**
     * Sets the array dimension in the x-direction (grid units)
     * Point data is cleared on resizing.
     */
    void nx(int val);

    /**
     * Gets the array dimension in the y-direction (grid units)
     *
     * @return size
     */
    int ny() const;

    /**
     * Sets the array dimension in the y-direction (grid units)
     * Point data is cleared on resizing.
     */
    void ny(int val);

    /**
     * Gets the array dimension in the z-direction (grid units)
     *
     * @return size
     */
    int nz() const;

    /**
     * Sets the array dimension in the z-direction (grid units)
     * Point data is cleared on resizing.
     */
    void nz(int val);

    /**
     * Gets the grid unit size (mm) in the X direction.
     * Requires SIMION 8.1.
     */
    double dx_mm() const;

    /**
     * Sets the grid unit size (mm) in the X direction.
     * Requires SIMION 8.1.
     */
    void dx_mm(double val);

    /**
     * Gets the grid unit size (mm) in the Y direction.
     * Requires SIMION 8.1.
     */
    double dy_mm() const;

    /**
     * Sets the grid unit size (mm) in the Y direction.
     * Requires SIMION 8.1.
     */
    void dy_mm(double val);

    /**
     * Gets the grid unit size (mm) in the Z direction.
     * Requires SIMION 8.1.
     */
    double dz_mm() const;

    /**
     * Sets the grid unit size (mm) in the Z direction.
     * Requires SIMION 8.1.
     */
    void dz_mm(double val);

    /**
     * Gets the PA# associated with this PA0 (if any).
     * @return PA# array.  NULL if none.
     */
    PA* pasharp() const;

    /**
     * Sets the PA# associated with this PA0.
     * This is only intended for PA0 arrays.
     * The PA# information is needed to properly save a PA0 file.
     *
     *   @code
     *   PA pasharp(PAArgs().file("test.pa#"));
     *   PA pa0();
     *   //... add code to create pa0 array here.
     *   pa0.pasharp(&pasharp);
     *   pa0.save("test.pa0");
     *   @endcode
     *
     * @param pasharp PA# array.  NULL clears it.
     */
    void pasharp(PA* pasharp);

    //IMPROVE:implement get() function analogous to set?

    /**
     * Sets multiple attributes at once.
     *
     * This can take the same set of parameters as the new() method.
     * This method is useful when the attributes are interdependent.
     *
     *   @code
     *   pa.set(PAArgs().nz(1).symmetry(CYLINDRICAL);
     *   @endcode
     *
     * See the individual setter methods for details on each parameter.
     */
    void set(const PAArgs& args);

    /**
     * Sets the array size in all dimensions (x, y, z) (grid units).
     * Point data is cleared on resizing.
     */
    void size(int nx, int ny, int nz = 1);

    /**
     * Retrieves the symmetry (cylindrical v.s. planar)
     * of the array.
     *
     * @return symmetry
     */
    symmetry_t symmetry() const;

    /**
     * Changes the symmetry of the potential array.
     *
     * @param val new symmetry
     */
    void symmetry(symmetry_t val);

    /// @}

    /**
     * @name Boundary and Coordinates
     * @{
     */

    /**
     * Determines if given integer point is inside the potential array.
     * Boundaries are considered included.
     *
     * Symmetry and mirroring ARE NOT handled.
     *
     * @param xi x-coordinate in grid units [0..nx-1]
     * @param yi y-coordinate in grid units [0..ny-1]
     * @param zi z-coordinate in grid units [0..nz-1]
     */
    bool inside(int xi, int yi, int zi = 0) const;

    /**
     * Determines is given real point is inside the potential array.
     * Boundaries are considered inside.
     *
     * Symmetry and mirroring ARE handled.
     *
     * @param x x-coordinate in grid units.
     * @param y y-coordinate in grid units.
     * @param z z-coordinate in grid units.
     */
    bool inside(double x, double y, double z = 0.0) const;

    /**
     * Convert a real point to its normalized form,
     * removing symmetry and mirroring.
     *
     * For example, (-5, 3, 4) transforms to (5, 3, 4) under x mirroring.
     *
     * @param x        x-coordinate in grid units
     * @param y        y-coordinate in grid units
     * @param z        z-coordinate in grid units
     * @return (x, y, z) coordinates in grid units (no mirror/symmetry)
     */
    Vector3R norm_grid_coords(double x, double y, double z) const;

    /**
     * Determines is given pixel is inside the potential array.
     * Boundaries are considered inside.
     * A pixel consists of all points between an including the
     * nearest grid points.
     * Note: inside_pixel(x,y,z) implies inside(x,y,z).
     *
     * Symmetry and mirroring ARE NOT handled.
     *
     * @param xi x-coordinate in grid units [0..nx-1]
     * @param yi y-coordinate in grid units [0..ny-1]
     * @param zi z-coordinate in grid units [0..nz-1]
     */
    bool voxel_inside(int xi, int yi, int zi = 0) const;

    /// @}

    /**
     * @name Point Setters/Getters
     * @{
     */

    /**
     * Sets all points to 0V, non-electrodes.
     *
     * This is different from enable_points(false) or ~PA(), which
     * actually releases the memory.
     */
    void clear_points();

    /**
     * Gets whether the given integer point is an electrode.
     * Symmetry and mirroring ARE NOT handled.
     *
     * @param xi x-coordinate in grid units [0..nx-1]
     * @param yi y-coordinate in grid units [0..ny-1]
     * @param zi z-coordinate in grid units [0..nz-1]
     * @return true if electrode, false if non-electrode
     */
     bool electrode(int xi, int yi, int zi = 0) const;

    /**
     * Gets whether the given real point is on an electrode.
     * All points are either electrodes or non-electrodes.
     * Electrodes may be either solids or grids.  Grids
     * have infinitesimal width.
     *
     * Symmetry and mirroring ARE handled.
     *
     * @param x x-coordinate in grid units.
     * @param y y-coordinate in grid units.
     * @param z z-coordinate in grid units.
     */
     bool electrode(double x, double y, double z = 0.0) const;

    /**
     * Sets the electrode status at the given integer point location.
     *
     * @param xi x-coordinate in grid units (0..nx-1)
     * @param yi y-coordinate in grid units (0..ny-1)
     * @param zi z-coordinate in grid units (0..nz-1)
     * @param is_electrode whether is electrode (true) or non-electrode (false)
     */
     void electrode(int xi, int yi, int zi, bool is_electrode);

    /**
     * Gets the electric or magnetic field vector at the given point.
     * The field is the gradient of the potential.
     *
     * Symmetry and mirroring ARE handled.
     *
     * @param x x-coordinate in grid units.
     * @param y y-coordinate in grid units.
     * @param z z-coordinate in grid units.
     * @return field vector
     */
    Vector3R field(double x, double y, double z = 0.0) const;

    /**
     * Sets the field (potential gradient) vector at the given point.
     *
     * The setting function internally performs the numerical
     * integration on the given field vectors to generate the
     * corresponding scalar potentials that must be stored in the PA
     * file. The setting function also has some special calling
     * requirements. First, the all points must initially be zero
     * volt, nonelectrodes. Second, the field setting method must be
     * called for all points in the array in lexographic order
     * (e.g. (0,0,0), (0,0,1), ... (0,0,nx()-1), (0,1,0), (0,1,1),
     * (0,1,nx()-1), ...).
     *
     *   @code
     *   // set
     *   for(int z = 0; z < pa.nz(); z++) {
     *   for(int y = 0; y < pa.ny(); y++) {
     *   for(int x = 0; z < pa.nz(); x++) {
     *       double ex = x;
     *       double ey = y**2;
     *       double ez = 0;
     *       pa.field(x, y, z, ex, ey, ez);
     *   }}}
     *   @endcode
     */
    void field(int xi, int yi, int zi, double ex, double ey, double ez,
               bool is_electrode = false);

    /**
     * Gets the potential and electrode status at the given point location.
     */
    PAPoint point(int xi, int yi, int zi) const;

    /**
     * Sets the potential and electrode status at the given point location.
     *
     * @param xi x-coordinate in grid units (0..nx-1)
     * @param yi y-coordinate in grid units (0..ny-1)
     * @param zi z-coordinate in grid units (0..nz-1)
     * @param electrode whether is electrode (true) or non-electrode (false)
     * @param potential new potential value
     */
    void point(int xi, int yi, int zi, bool electrode, double potential);


    /**
     * Gets the potential at the given integer point location.
     * The point may be either an electrode or non-electrode.
     * inside(xi, yi, zi) must be true.
     *
     * @param xi x-coordinate in grid units [0..nx-1]
     * @param yi y-coordinate in grid units [0..ny-1]
     * @param zi z-coordinate in grid units [0..nz-1]
     * @return potential
     */
    double potential(int xi, int yi, int zi = 0) const;

    /**
     * Retrieve the potential at the given real point location.
     * Interpolation is used for points between grid points.
     * inside(x, y, z) must be true.
     *
     * Symmetry and mirroring ARE handled.
     *
     * @param x x-coordinate in grid units.
     * @param y y-coordinate in grid units.
     * @param z z-coordinate in grid units.
     */
    double potential(double x, double y, double z = 0.0) const;

    /**
     * Sets the potential at the given integer point.
     * The electrode/non-electrode state is preserved.
     *
     * @param xi x-coordinate in grid units.
     * @param yi y-coordinate in grid units.
     * @param zi z-coordinate in grid units.
     * @param potential new potential in volts.
     */
    void potential(int xi, int yi, int zi, double potential);

    /**
     * Get the raw value at the given integer point location.
     *
     * The raw value is defined by
     * \li  raw = potential + (electrode ? 2 * max_voltage() : 0)
     *
     * (You must have previously called create or load before
     * using this.)
     *
     * @param xi x-coordinate in grid units (0..nx-1)
     * @param yi y-coordinate in grid units (0..ny-1)
     * @param zi z-coordinate in grid units (0..nz-1)
     * @return raw value
     */
    double raw_value(int xi, int yi, int zi = 0) const;

    /**
     * Get the raw value at the given real point location.
     * The raw value is defined by
     * - raw = potential + (electrode ? 2 * max_voltage : 0).
     */
    //IMPROVE:implement?
    //double raw_value(double x, double y, double z = 0.0) const;


    /**
     * Set the raw value at the given integer point location.
     *
     * The raw value is defined by
     * \li raw = potential + (electrode ? 2 * max_voltage : 0).
     *
     * (You must have previously called create or load before
     * using this.)
     *
     * @param xi x-coordinate in grid units (0..nx-1)
     * @param yi y-coordinate in grid units (0..ny-1)
     * @param zi z-coordinate in grid units (0..nz-1)
     * @param val new value
     */
    void raw_value(int xi, int yi, int zi, double val);


    /**
     * Sets the given pixel as solid (electrode, non-grid)
     * and the voltage to the given value.
     *
     * The pixel is consists of the space bounded by
     * [x, y, z] and [x+1, y+1, z+1] (3D planar arrays) or
     * [x, y] and [x+1, y+1] (cylindrical or 2D planar arrays).
     *
     * @param xi x-coordinate in grid units.
     * @param yi y-coordinate in grid units.
     * @param zi z-coordinate in grid units.
     * @param is_electrode whether to set to electrode points
     *    (else non-electrode).
     * @param potential potential to set points to. 
     */
     void solid(int xi, int yi, int zi, bool is_electrode, double potential);

    /**
     * Gets whether the given pixel is a solid point.
     * All solid points are electrodes.
     * Electrodes may be either solids or grids.  
     * The pixel is consists of the space bounded by
     * [x, y, z] and [x+1, y+1, z+1] (3D planar arrays) or
     * [x, y] and [x+1, y+1] (cylindrical or 2D planar arrays).
     *
     * @param xi x-coordinate in grid units [0..nx-1]
     * @param yi y-coordinate in grid units [0..ny-1]
     * @param zi z-coordinate in grid units [0..nz-1]
     * @return true if solid, else false.
     */
     bool solid(int xi, int yi, int zi = 0) const;

     ///@}


    /**
     * @name Parsing
     * @{
     */

     /**
      * Parses an ASCII PA file.
      * Typically you don't need to use this since the "load"
      * method calls this.
      *
      * @param is input stream (binary or ASCII)
      * @param handler object that parsing events will be sent to
      *
      * Throws string on error.
      */
     void parse_ascii(std::istream& is, PATextHandler& handler);

     /// @}

    /**
     * @name Attribute Checking
     * @{
     */


    /**
     * Checks whether the given combination of
     * attributes is valid.
     * Sets error() on false.
     * Any subset of the above named parameters may be
     * specified.  This method is useful in cases
     * when the attributes are interdependent.
     */
    bool check(const PAArgs& args);

    /**
     * Checks whether the given field type is valid.
     * Valid field types are ELECTROSTATIC and MAGNETIC.
     * Sets error() on false.
     */
    bool check_field_type(field_t val);

    /**
     * Checks whether the given mode is valid.
     * Sets error() on false.
     */
    bool check_mode(int val);

    /**
     * Checks whether the given max voltage valid is valid.
     * Sets error() on false.
     */
    bool check_max_voltage(double val);

    /**
     * Checks whether the given ng magnetic scaling constant is valid.
     * Sets error() on false.
     */
    bool check_ng(double val);

    /**
     * Checks whether the given grid dimensions in the x direction is valid.
     * Sets error() on false.
     */
    bool check_nx(int val);

    /**
     * Checks whether the given grid dimensions in the y direction is valid.
     * Sets error() on false.
     */
    bool check_ny(int val);

    /**
     * Checks whether the given grid dimensions in the z direction is valid.
     * Sets error() on false.
     */
    bool check_nz(int val);

    /**
     * Checks whether the given set of grid dimensions
     * in the x, y, and z directions is valid as a whole.
     * Sets error() on false.
     *
     * Note that check_nx(nx) and check_ny(ny) and check_nz(nz) implies
     * check_size(nx, ny, nz), although the converse is not necessarily
     * true.
     */
    bool check_size(int nx, int ny, int nz = 1);

    /**
     * Checks whether the given symmetry is valid.
     * Valid symmetries are PLANAR and CYLINDRICAL.
     * Sets error() on false.
     */
    bool check_symmetry(symmetry_t val);

    /**
     * Checks whether the given grid unit size (mm) in X direction is valid.
     * Sets error() on false.
     */
    bool check_dx_mm(double val);

    /**
     * Checks whether the given grid unit size (mm) in Y direction is valid.
     * Sets error() on false.
     */
    bool check_dy_mm(double val);

    /**
     * Checks whether the given grid unit size (mm) in Z direction is valid.
     * Sets error() on false.
     */
    bool check_dz_mm(double val);

    /**
     * Get last error message generated by one of the check calls.
     */
    inline std::string error() const;

     ///@}

    /**
     * Returns string representation of symmetry value
     * (as returned by symmetry()).
     *
     * @return "cylindrical" or "planar"
     */
    static std::string symmetry_string(symmetry_t val);

    /**
     * Returns string representation of symmetry value
     * (as returned by field_type()).
     *
     * @return "electrostatic" or "planar"
     */
    static std::string field_string(field_t val);

    /** for internal use */
    ptrdiff_t pos_(int xi, int yi, int zi) const;
    /** for internal use */
    double potential_(ptrdiff_t n) const;

private:
    int        mode_;           // mode must be -1
    field_t    field_type_;
    symmetry_t symmetry_;
    bool       mirror_x_;
    bool       mirror_y_;
    bool       mirror_z_;
    int        nx_;             // array's x dimension size
    int        ny_;             // array's y dimension size
    int        nz_;             // array's z dimension size
    bool       fast_adjustable_;
    double     max_voltage_;    // max voltage allowed for pa
    double     ng_;             // number of grid points between poles
    double     dx_mm_;    // grid size in X direction (mm)
    double     dy_mm_;    // grid size in Y direction (mm)
    double     dz_mm_;    // grid size in Z direction (mm)
    bool       enable_points_;

    double*    points_;         // data points

    PATextImpl_* pat_;
    PA*          pasharp_;      // associated PA# (if any)

    PAAllocator * allocator_; // memory allocator

    std::string error_;  // last error message


    std::string fail_point_(int x, int y, int z) const;
    std::string fail_point_(double x, double y, double z) const;

    /**
     * Creates a the point data array (may be very large).
     * Normally, you don't need to use this since it it called
     * by "create".
     * Any existing data array is first destroyed.
     */
    void create_points_();

    /**
     * Frees any data in the array.
     * This undoes a "create", and you must subsequently call
     * "create" if you want to use the object again.
     * Normally, you don't need to call this yourself becuase
     * it is called automatically on object destruction.
     */
    void destroy_points_();

    /**
     * Determines is given point is inside the potential array.
     * The array must be cylindrical.
     * Boundaries are included.
     *
     * Symmetry and mirroring ARE handled.
     *
     * @param x x-coordinate in grid units.
     * @param r r-coordinate (y) in grid units.
     */
    bool inside_cylindrical_(double x, double r) const;

    // throws string on error
    void load_ascii_(std::istream& is);
    // throws string on error
    void load_binary_(std::istream& is);

    // throws string on error
    void save_ascii_(std::ostream& os, const PAFormat& opt);
    // throws string on error
    void save_binary_(std::ostream& os, const PAFormat& opt);

    // attribute checking
    bool fail_string_(const std::string& str);
    bool fail_mode_(int val);
    bool fail_max_voltage_(double val);
    bool fail_nx1_(int val);
    bool fail_nx2_(int val);
    bool fail_ny1_(int val);
    bool fail_ny2_(int val);
    bool fail_nz1_(int val);
    bool fail_nz2_(int val);
    bool fail_ng_(double val);
    bool fail_field_type_(field_t val);
    bool fail_symmetry_(symmetry_t val);
    bool fail_size_(int nx, int ny, int nz);
    bool fail_d_mm_(double val, char axis, int direction);
};



//==============================================================
//=== Inline Code
//==============================================================

#ifndef DOXYGEN_SHOULD_SKIP_THIS
#define SL_MAKE_ARGS \
    (PAArgs().nx(nx_).ny(ny_).nz(nz_).symmetry(symmetry_). \
     mirror_x(mirror_x_).mirror_y(mirror_y_).mirror_z(mirror_z_))
#endif


// IMPLEMENTATION PAHeader

inline PAHeader::PAHeader(
    int          mode,
    field_t      field_type,
    symmetry_t   symmetry,
    double       max_voltage,
    int          nx,
    int          ny,
    int          nz,
    bool         mirror_x,
    bool         mirror_y,
    bool         mirror_z,
    double       ng,
    double       dx_mm,
    double       dy_mm,
    double       dz_mm
) :
    mode_        (mode),
    symmetry_    (symmetry != 0 ? 1 : 0),
    max_voltage_ (max_voltage),
    nx_          (nx),
    ny_          (ny),
    nz_          (nz),
    mirror_      ( (mirror_x ? MIRROR_X : 0) |
                   (mirror_y ? MIRROR_Y : 0) |
                   (mirror_z ? MIRROR_Z : 0) |
                   (field_type == MAGNETIC ? MAGNETIC_PA : 0) |
                   (ng >= 1 && ng <= 90000 && int(ng) == ng ? ((int)ng << 4) : 0)
                 ),
    dx_mm_ (dx_mm),
    dy_mm_ (dy_mm),
    dz_mm_ (dz_mm)
{
}

inline field_t PAHeader::field_type() const
{
    return (mirror_ & MAGNETIC_PA) != 0 ? MAGNETIC : ELECTROSTATIC;
}
inline bool PAHeader::mirror_x() const { return (mirror_ & MIRROR_X) != 0; }
inline bool PAHeader::mirror_y() const { return (mirror_ & MIRROR_Y) != 0; }
inline bool PAHeader::mirror_z() const { return (mirror_ & MIRROR_Z) != 0; }
inline double PAHeader::ng() const { return (mirror_ >> 4) & ((1 << 17) - 1); }
inline symmetry_t PAHeader::symmetry() const {
    return symmetry_ == PLANAR ? PLANAR : CYLINDRICAL;
}
inline ptrdiff_t PAHeader::num_points() const {
    return static_cast<ptrdiff_t>(nx_) * static_cast<ptrdiff_t>(ny_) *
           static_cast<ptrdiff_t>(nz_);
}


// IMPLEMENTATION PATextHeader

inline void PATextHeader::enable_column(int idx, point_column_t t)
{
    if(idx >= (int)columns_.size())
        columns_.resize(idx+1);
    if(idx != -1) {
        columns_enabled_ |= t;
        columns_[idx] = t;
    }
    else {
        columns_enabled_ &= ~t;
        columns_[idx] = (point_column_t)0;
    }
}
inline PATextHeader::point_column_t PATextHeader::column(int idx) const
{ return columns_[idx]; }
inline int PATextHeader::column_count() const { return (int)columns_.size(); }
inline int PATextHeader::enabled_columns() const { return columns_enabled_; }
inline bool PATextHeader::is_column_enabled(point_column_t t) const
{
    return (columns_enabled_ & t) != 0;
}



// IMPLEMENTATION PAArgs

inline int PAArgs::defined() { return valid_; }
inline bool PAArgs::is_set_(PAArgs::arg_t val) const { return (valid_ & val) != 0; } 
inline void PAArgs::set_(PAArgs::arg_t val)          { valid_ |= val; }

// IMPLEMENTATION: Vector3R

inline        Vector3R::Vector3R(double x, double y, double z) :
    x_(x), y_(y), z_(z)
{ }
inline void   Vector3R::set(double x, double y, double z)
{ x_ = x; y_ = y; z_ = z; }
inline double Vector3R::x() const     { return x_; }
inline void   Vector3R::x(double val) { x_ = val; }
inline double Vector3R::y() const     { return y_; }
inline void   Vector3R::y(double val) { y_ = val; }
inline double Vector3R::z() const     { return z_; }
inline void   Vector3R::z(double val) { z_ = val; }

// IMPLEMENTATION PA

inline std::string PA::fail_point_(double x, double y, double z) const
{
    return (std::string)"point (" + str(x) + "," + str(y) + "," + str(z) +
        ") out of bounds (" + str(nx_) + "," + str(ny_) + "," + str(nz_) + ").";
}

inline std::string PA::fail_point_(int xi, int yi, int zi) const
{
    return (std::string)"point (" + str(xi) + "," + str(yi) + "," + str(zi) +
        ") out of bounds (" + str(nx_) + "," + str(ny_) + "," + str(nz_) + ").";
}

inline ptrdiff_t PA::pos_(int xi, int yi, int zi) const
{
    return (static_cast<ptrdiff_t>(zi) * static_cast<ptrdiff_t>(ny_) + static_cast<ptrdiff_t>(yi))
           * static_cast<ptrdiff_t>(nx_) + static_cast<ptrdiff_t>(xi);
}

inline double PA::potential_(ptrdiff_t n) const {
    double val = points_[n];
    if(val > max_voltage()) // electrode
        val -= 2*max_voltage();
    return val;
}


inline bool PA::enable_points() const { return enable_points_; }
inline void PA::enable_points(bool val) {
    if(val && !enable_points_) destroy_points_();
    if(!val && enable_points_) create_points_();
    enable_points_ = val;

}

inline bool PA::fast_adjustable() const { return fast_adjustable_; }
inline void PA::fast_adjustable(bool val) { fast_adjustable_ = val; }

inline field_t PA::field_type() const { return field_type_; }
inline void PA::field_type(field_t val)
{
    field_type_ = val;
}

inline double PA::max_voltage() const { return max_voltage_; }

inline bool PA::mirror_x() const { return mirror_x_; }
inline void PA::mirror_x(bool val)
{
    mirror_x_ = !!val;
}

inline bool PA::mirror_y() const { return mirror_y_; }
inline void PA::mirror_y(bool val)
{
    sl_assert(check(SL_MAKE_ARGS.mirror_y(val)), "mirror_y", error());
    mirror_y_ = !!val;
}

inline bool PA::mirror_z() const { return mirror_z_; }
inline void PA::mirror_z(bool val)
{
    sl_assert(check(SL_MAKE_ARGS.mirror_z(val)), "mirror_z", error());

    mirror_z_ = !!val;
}

inline int PA::mode() const
{
    if (mode_ == -1 && (dx_mm() != 1.0 || dy_mm() != 1.0 ||
                        dz_mm() != 1.0))
        return -2;
    return mode_;
}
inline void PA::mode(int val)
{
    sl_assert(check_mode(val), "mode", error());
    mode_ = val;
}

inline double PA::ng() const { return ng_; }
inline void PA::ng(double val)
{
    // IMPROVE: check ng >= 1 (not 0) if magnetic
    sl_assert(check_ng(val), "ng", error());
    ng_ = val;
}

inline ptrdiff_t PA::num_points() const {
    return static_cast<ptrdiff_t>(nx_) * static_cast<ptrdiff_t>(ny_) *
           static_cast<ptrdiff_t>(nz_);
}

inline ptrdiff_t PA::num_voxels() const {
    ptrdiff_t num = static_cast<ptrdiff_t>(nx_ - 1) *
                    static_cast<ptrdiff_t>(ny_ - 1);
    if(nz_ != 1) num *= static_cast<ptrdiff_t>(nz_ - 1);
    return num;
}

inline int PA::nx() const { return nx_; }
inline void PA::nx(int val)
{
    sl_assert(check_nx(val), "nx", error());
    nx_ = val;
}

inline int PA::ny() const { return ny_; }
inline void PA::ny(int val)
{
    sl_assert(check_ny(val), "ny", error());
    ny_ = val;
}

inline int PA::nz() const { return nz_; }
inline void PA::nz(int val)
{
    sl_assert(check_nz(val), "nz", error());
    nz_ = val;
}

inline double PA::dx_mm() const { return dx_mm_; }
inline void PA::dx_mm(double val)
{
    sl_assert(check_dx_mm(val), "dx_mm", error());
    dx_mm_ = val;
}

inline double PA::dy_mm() const { return dy_mm_; }
inline void PA::dy_mm(double val)
{
    sl_assert(check_dy_mm(val), "dy_mm", error());
    dy_mm_ = val;
}

inline double PA::dz_mm() const { return dz_mm_; }
inline void PA::dz_mm(double val)
{
    sl_assert(check_dz_mm(val), "dz_mm", error());
    dz_mm_ = val;
}


inline PA* PA::pasharp() const { return pasharp_; }
inline void PA::pasharp(PA* pasharp) { pasharp_ = pasharp; }

inline symmetry_t PA::symmetry() const { return (symmetry_t)symmetry_; }
inline void PA::symmetry(symmetry_t val)
{
    symmetry_ = (val == CYLINDRICAL) ? CYLINDRICAL : PLANAR;
}


inline bool PA::electrode(int xi, int yi, int zi) const
{
    sl_assert(inside(xi, yi, zi), "electrode", fail_point_(xi,yi,zi));

    return raw_value(xi, yi, zi) > max_voltage();
}

inline void PA::electrode(int xi, int yi, int zi, bool is_electrode)
{
    sl_assert(inside(xi, yi, zi), "point", fail_point_(xi, yi, zi));

    ptrdiff_t pos = pos_(xi,yi,zi);
    if(points_[pos] > max_voltage_) {
        if(!is_electrode) points_[pos] -= 2 * max_voltage_;
    }
    else {
        if(is_electrode) points_[pos] += 2 * max_voltage_;
    }
}

inline PAPoint PA::point(int xi, int yi, int zi) const
{
    return PAPoint(electrode(xi,yi,zi), potential(xi,yi,zi));
}

inline void PA::point(int xi, int yi, int zi, bool electrode, double potential)
{
    sl_assert(inside(xi, yi, zi), "point", fail_point_(xi, yi, zi));
    if (potential > max_voltage()) {
        max_voltage(potential * 2.0);
    }

    double val = electrode ? 2*max_voltage() + potential
                           : potential;
    raw_value(xi, yi, zi, val);
}

inline double PA::potential(int xi, int yi, int zi) const
{
    sl_assert(inside(xi, yi, zi), "potential", fail_point_(xi, yi, zi));

    double val = raw_value(xi, yi, zi);
    if(val > max_voltage()) // electrode
        val -= 2*max_voltage();

    // sl_assert(abs(val) <= max_voltage(), "potential", "...", "voltage out of range")

    return val;
}

inline void PA::potential(int xi, int yi, int zi, double potential)
{
    sl_assert(inside(xi, yi, zi), "potential", fail_point_(xi, yi, zi));
    if (potential > max_voltage()) {
        max_voltage(potential * 2.0);
    }

    ptrdiff_t pos = pos_(xi,yi,zi);
    bool is_electrode = (points_[pos] > max_voltage_);
    points_[pos] = potential;
    if(is_electrode) points_[pos] += 2 * max_voltage_;
}

inline double PA::raw_value(int xi, int yi, int zi) const
{
    sl_assert(inside(xi, yi, zi), "raw_value", fail_point_(xi,yi,zi));

    return points_[pos_(xi,yi,zi)];
}
inline void PA::raw_value(int xi, int yi, int zi, double val)
{
    sl_assert(inside(xi, yi, zi), "raw_value", fail_point_(xi, yi, zi));

    points_[pos_(xi,yi,zi)] = val;
}


inline bool PA::check_mode(int val)
{
    if (val != -1 && val != -2) return fail_mode_(val);
    return true;
}

inline bool PA::check_max_voltage(double val)
{
    if(val <= 0) return fail_max_voltage_(val);
    return true;
} //q:ok?

inline bool PA::check_nx(int val)
{
    if(val < 3) return fail_nx1_(val);
    if(val > 90000) return fail_nx2_(val);
    return true;
}

inline bool PA::check_ny(int val)
{
    if(val < 3) return fail_ny1_(val);
    if(val > 90000) return fail_ny2_(val);
    return true;
}

inline bool PA::check_nz(int val)
{
    if(val < 1) return fail_nz1_(val);
    if(val > 90000) return fail_nz2_(val);
    return true;
}

inline bool PA::check_ng(double val)
{
    if(val < 0) return fail_ng_(val);
    return true;
}

inline bool PA::check_field_type(field_t val)
{
    if(val != ELECTROSTATIC && val != MAGNETIC)
        return fail_field_type_(val);
    return true;
}

inline bool PA::check_symmetry(symmetry_t val)
{
    if(val != PLANAR && val != CYLINDRICAL)
        return fail_symmetry_(val);
    return true;
}
inline bool PA::check_size(int nx, int ny, int nz)
{
    if(!(check_nx(nx) && check_ny(ny) && check_nz(nz))) return false;
    if(mult_overflow(nx,ny) ||
       mult_overflow(static_cast<ptrdiff_t>(nx)*static_cast<ptrdiff_t>(ny),nz) ||
       static_cast<ptrdiff_t>(nx) *
       static_cast<ptrdiff_t>(ny) *
       static_cast<ptrdiff_t>(nz) > MAX_POINTS)
        return fail_size_(nx, ny, nz);
    return true;
}

inline bool PA::check_dx_mm(double val)
{
    if (val < 1e-6 ) return fail_d_mm_(val, 'x', -1);
    if (val > 900.0) return fail_d_mm_(val, 'x',  1);
    return true;
}

inline bool PA::check_dy_mm(double val)
{
    if (val < 1e-6 ) return fail_d_mm_(val, 'y', -1);
    if (val > 900.0) return fail_d_mm_(val, 'y',  1);
    return true;
}

inline bool PA::check_dz_mm(double val)
{
    if (val < 1e-6 ) return fail_d_mm_(val, 'z', -1);
    if (val > 900.0) return fail_d_mm_(val, 'z',  1);
    return true;
}

inline std::string PA::error() const { return error_; }

#undef SL_MAKE_ARGS

} // end namespace

#endif // first include
