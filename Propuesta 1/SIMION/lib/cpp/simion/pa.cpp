/**
 * @file pa.cpp
 * SIMION potential array class implementation.
 *
 * @author David Manura (c) 2003-2007 Scientific Instrument Services, Inc.
 * Licensed under the terms of the SIMION SL Toolkit.
 * $Revision$ $Date$ Created 2003-11.
 */

#include <simion/task.h>
#include <simion/pa.h>
#include <simion/util.h>


#include <fstream>
#include <iostream>
#include <sstream>
#include <vector>
#include <cmath>
#include <cerrno>
#include <cstring>

#define PDIFF(x) static_cast<ptrdiff_t>(x)

using namespace std;
using namespace simion;

namespace simion {

enum type_t {
    T_NULL, // EOF
    T_EOL,

    T_BEGIN_POTENTIAL_ARRAY,
    T_BEGIN_HEADER,
    T_MODE,
    T_SYMMETRY,
    T_MAX_VOLTAGE,
    T_NX,
    T_NY,
    T_NZ,
    T_MIRROR_X,
    T_MIRROR_Y,
    T_MIRROR_Z,
    T_FIELD_TYPE,
    T_NG,
    T_DX_MM,
    T_DY_MM,
    T_DZ_MM,
    T_FAST_ADJUSTABLE,
    T_DATA_FORMAT,

    T_END_HEADER,
    T_BEGIN_POINTS,
    T_END_POINTS,
    T_END_POTENTIAL_ARRAY,

    T_PLANAR,
    T_CYLINDRICAL,
    T_ELECTROSTATIC,
    T_MAGNETIC,

    T_X,
    T_Y,
    T_Z,
    T_IS_ELECTRODE,
    T_POTENTIAL,
    T_RAW_VALUE,
    T_FIELD_X,
    T_FIELD_Y,
    T_FIELD_Z,

    T_NUMBER
};

struct token_t_
{
    type_t type;
    char str[256];
    float fval;

    token_t_() : type(T_NULL), fval(0.0)
    { str[0] = '\0'; }
};


enum enable_fields_t
{
    F_MODE = (1 << 0),
    F_MAX_VOLTAGE = (1 << 1),
    F_NX = (1 << 2),
    F_NY = (1 << 3),
    F_NZ = (1 << 4),
    F_MIRROR_X = (1 << 5),
    F_MIRROR_Y = (1 << 6),
    F_MIRROR_Z = (1 << 7),
    F_FIELD = (1 << 8),
    F_SYMMETRY = (1 << 9),
    F_NG = (1 << 10),
    F_DX_MM = (1 << 10),
    F_DY_MM = (1 << 11),
    F_DZ_MM = (1 << 12),
    F_FAST_ADJUSTABLE = (1 << 13)
};


// for reading PATXT files.
class MyTextHandler_ : public PATextHandler
{
private:
public:
    PA* pa_;
    MyTextHandler_(PA* pa) : pa_(pa) { }
    virtual ~MyTextHandler_() { }
    void process_header(const PATextHeader& header);
    void process_point(const PAPointInfo& info);
};

class PATextImpl_
{
public:
    token_t_ tok;
    std::istream* is;
    PATextHandler* handler;
    int linenum_;
    bool eof_found_;

    PATextHeader header_;
    int fields_set_; // ORed enabled_fields_t

    Task* status_;
    PA* pa_;

    PATextImpl_(PA* pa) : is(NULL), handler(NULL), linenum_(0), eof_found_(false),
                    fields_set_(0), status_(NULL), pa_(pa) { }
    void construct(PA* pa) { pa_ = pa; }

    void next_token();
    void parse_header();
    void parse_data();

    void eat_line();
    void eat_whitespace();
    void read_word(const char* term_chars);
    void parse_ascii(std::istream& is1, PATextHandler& handler);
    void parse_exception(const std::string& str);

    void parse_nl();
    void parse_nls();
};

// Default memory allocator.
class PAAllocatorDefault : public PAAllocator
{
public:
    virtual void * malloc(size_t nbytes) {
        return ::malloc(nbytes);
    }
    virtual void free(void * data) {
        ::free(data);
    }
};

static PAAllocatorDefault s_allocator;

// IMPLEMENTATION

//=== Utilities

template<class T>
string point_to_string_(T x, T y, T z)
{
     stringstream ss;
     ss << "(" << x << "," << y << "," << z << ")";
     return ss.str();
}

// IMPLEMENTATION PA

#define SL_INIT \
    mode_           (-1),     \
    field_type_     (ELECTROSTATIC), \
    symmetry_       (PLANAR), \
    mirror_x_       (false),  \
    mirror_y_       (false),  \
    mirror_z_       (false),  \
    nx_             (3),      \
    ny_             (3),      \
    nz_             (1),      \
    fast_adjustable_(false),  \
    max_voltage_    (100000), \
    ng_             (100.0),  \
    dx_mm_          (1.0),    \
    dy_mm_          (1.0),    \
    dz_mm_          (1.0),    \
    enable_points_  (true),   \
                              \
    points_         (NULL),   \
    pat_            (NULL),   \
    pasharp_        (NULL),   \
    allocator_      (&s_allocator)

PA::PA() :
    SL_INIT
{
    pat_ = new PATextImpl_(this);
    create_points_();
}

PA::PA(const PAArgs& args) :
    SL_INIT
{
    pat_ = new PATextImpl_(this);
    set(args); // also creates points
}

#undef SL_INIT

PA::~PA()
{
    if(pat_ != NULL)
        delete pat_;
    destroy_points_();
}

string PA::header_string() const
{
    stringstream ss;
    ss << "begin_header"         << endl
       << "    mode "            << mode() << endl
       << "    symmetry "        << symmetry_string(symmetry()) << endl
       << "    max_voltage "     << max_voltage() << endl
       << "    nx "              << nx() << endl
       << "    ny "              << ny() << endl
       << "    nz "              << nz() << endl
       << "    mirror_x "        << (mirror_x() ? 1 : 0) << endl
       << "    mirror_y "        << (mirror_y() ? 1 : 0) << endl
       << "    mirror_z "        << (mirror_z() ? 1 : 0) << endl
       << "    field_type "      << field_string(field_type()) << endl
       << "    ng "              << ng() << endl
    ;
    if (mode() <= -2)
    ss << "    dx_mm "           << dx_mm() << endl
       << "    dy_mm "           << dy_mm() << endl
       << "    dz_mm "           << dz_mm() << endl
    ;
    ss
       << "    fast_adjustable " << (fast_adjustable() ? 1 : 0) << endl
       << "end_header"           << endl
    ;
    return ss.str();
}


void PA::set_status(Task* status)
{
    pat_->status_ = status;
}

void PA::size(int nx, int ny, int nz)
{
    sl_assert(check(PAArgs().
        nx       (nx).
        ny       (ny).
        nz       (nz).
        symmetry (symmetry_).
        mirror_x (mirror_x_).
        mirror_y (mirror_y_).
        mirror_z (mirror_z_)
    ), "size", error());
    nx_ = nx;
    ny_ = ny;
    nz_ = nz;

    create_points_();
}


void PA::load(const string& path)
{
    ifstream is;

    string::size_type pound_pos = path.rfind("#");
    //string::size_type patxt_pos = tolower(path).rfind(".patxt");
    //bool ascii = patxt_pos != -1 && patxt_pos == path.size() - 6;

    if(pat_->status_ != NULL) {
        pat_->status_->set_message("Loading PA...");
    }

    is.open(path.c_str(), ios::binary); // note: even PATXT is read in binary mode
    if(!is) {
        stringstream ss;
        ss << "Could not open file " << path << " for reading. " << strerror(errno);
        throw ss.str();
    }
    load(is);

    fast_adjustable_ =
        (pound_pos != string::npos && pound_pos == path.size() - 1);
}

void PA::load(istream& is)
{
    int val = 0;
    if(!is.read(reinterpret_cast<char*>(&val), sizeof(int)))
        throw string("File empty or too small.");
    PAFormat::format_t format = (val >= -255 && val <= -1) ?
        PAFormat::BINARY : PAFormat::ASCII;

    is.seekg(0, ios::beg);

    if(format == PAFormat::BINARY)
        load_binary_(is);
    else // ASCII
        load_ascii_(is);
}

void PA::save(const std::string& path, const PAFormat& opt)
{
    if(pat_->status_ != NULL) {
        pat_->status_->set_message("Saving PA...");
    }

    ofstream os;
    os.open(path.c_str(), (opt.format() == PAFormat::BINARY) ? (ios::binary | ios::out) : (ios::out));
    if(!os) {
        stringstream ss;
        ss << "Could not open file " << path << " for writing. " << strerror(errno);
        throw ss.str();
    }
    save(os, opt);
}

void PA::save(std::ostream& os, const PAFormat& opt)
{
    if(opt.format() == PAFormat::BINARY)
        save_binary_(os, opt);
    else // PAFormat::ASCII
        save_ascii_(os, opt);
}


void PA::clear_points()
{
    ptrdiff_t n = num_points();
    for(ptrdiff_t idx = 0; idx < n; idx++)
        points_[idx] = 0.0;
}

void PA::set(const PAArgs& args_orig)
{
#   define SL_ARGS_EQUAL(name,value) \
        (args.name ## _defined() && args.name() == value)
#   define SL_ARGS_NOTEQUAL(name,value) \
        (args.name ## _defined() && args.name() != value)
#   define SL_DEFAULT(name) \
        if(!args.name ## _defined()) args.name(name ## _);
#   define SL_SET(name) \
        if(args.name ## _defined()) name ## _ = args.name();
#   define SL_CHECK(name) \
        sl_assert(!args.name ## _defined() || check_ ## name(args.name()), "set", error());


    PAArgs args = args_orig;

    if(args.allocator()) {
        allocator_ = args.allocator();
    }

    if(args.file_defined()) {
        sl_assert(
            (args.defined() & ~(PAArgs::A_file | PAArgs::A_enable_points)) == 0,
            "set", "Named parameter 'file' cannot coexist with other named parameters except 'enable_points'."
        );
        if(args.enable_points_defined()) enable_points_ = args.enable_points();
        load(args.file());
    }
    else {
        //removed: mirror field alias

        // defaults
        if(SL_ARGS_EQUAL(symmetry, CYLINDRICAL))
            if(!args.mirror_y_defined()) args.mirror_y(1);


        // single-attribute checks
        SL_CHECK(mode)
        SL_CHECK(max_voltage)
        SL_CHECK(field_type)
        SL_CHECK(ng)
        SL_CHECK(symmetry)
        SL_CHECK(dx_mm)
        SL_CHECK(dy_mm)
        SL_CHECK(dz_mm)
        // ignore: fast_adjustable, enable_points
        // ignore: mirror_x, mirror_y, mirror_z
        // skip: nx, ny, nz (for now)

        if(args.mirror_x_defined() || args.mirror_y_defined() || args.mirror_z_defined()) {
            SL_DEFAULT(mirror_x)
            SL_DEFAULT(mirror_y)
            SL_DEFAULT(mirror_z)
            //mirror_str = ''
            //if mirror_x: mirror_str += 'x'
            //if mirror_y: mirror_str += 'y'
            //if mirror_z: mirror_str += 'z'
            //assert check_mirror(mirror_str)[0], check_mirror(mirror_str)[1]
        }

        if(args.nx_defined() || args.ny_defined() || args.nz_defined()) {
            SL_DEFAULT(nx)
            SL_DEFAULT(ny)
            SL_DEFAULT(nz)
            sl_assert(check_size(args.nx(), args.ny(), args.nz()), "set", error());
        }

        SL_DEFAULT(symmetry)
        SL_DEFAULT(mirror_x)
        SL_DEFAULT(mirror_y)
        SL_DEFAULT(mirror_z)
        SL_DEFAULT(nx)
        SL_DEFAULT(ny)
        SL_DEFAULT(nz)
        sl_assert(check(args), "set", error());

        // invariant: no failure below this point (except for size)

        // set
        SL_SET(mode)
        SL_SET(max_voltage)
        SL_SET(field_type)
        SL_SET(ng)
        SL_SET(fast_adjustable)
        SL_SET(symmetry)
        SL_SET(mirror_x)
        SL_SET(mirror_y)
        SL_SET(mirror_z)
        SL_SET(dx_mm)
        SL_SET(dy_mm)
        SL_SET(dz_mm)
        if(args.enable_points_defined()) enable_points(args.enable_points());

        // note: resizing is destructive
        if(SL_ARGS_NOTEQUAL(nx, nx_) || SL_ARGS_NOTEQUAL(ny, ny_)
            || SL_ARGS_NOTEQUAL(nz, nz_) || points_ == NULL)
        {
            size(args.nx(), args.ny(), args.nz()); // throws on memory failure
        }
    }

#   undef SL_CHECK
#   undef SL_SET
#   undef SL_DEFAULT
#   undef SL_ARGS_NOTEQUAL
#   undef SL_ARGS_EQUAL
}

bool PA::inside(int x, int y, int z) const
{
    bool yes = (x >= 0 && x < nx() &&
                y >= 0 && y < ny() &&
                z >= 0 && z < nz());
    //cout << x << " " << y << " " << z << " " << yes << endl;
    return yes;
}

bool PA::inside(double x, double y, double z) const
{
    bool yes = false;
    if(symmetry() == PLANAR) {
        yes =
            ((x >= 0.0) ? (x <= nx()-1) : mirror_x() ? (-x <= nx()-1) : false) &&
            ((y >= 0.0) ? (y <= ny()-1) : mirror_y() ? (-y <= ny()-1) : false) &&
            (  (nz() == 1) || // infinite extent
               ((z >= 0.0) ? (z <= nz()-1) : mirror_z() ? (-z <= nz()-1) : false)
            )
        ;
    }
    else if(symmetry() == CYLINDRICAL) {
        double r = sqrt(y*y + z*z);
        yes = inside_cylindrical_(x, r);
    }
    else { sl_assert(false, "inside", "bad symmetry"); }
    return yes;
}

Vector3R PA::norm_grid_coords(double x, double y, double z) const
{
    // cout << x << " " << y << " " << z << endl;
    sl_assert(inside(x, y, z), "norm_grid_coords", fail_point_(x, y, z));

    double xeff = (x < 0) ? -x : x;  // if mirroring
    double yeff = (y < 0) ? -y : y;
    double zeff = (z < 0) ? -z : z;

    Vector3R ret;
    if(symmetry() == PLANAR) {
        ret.x(xeff);
        ret.y(yeff);
        if(nz() == 1) { // 2D
            ret.z(0.0);
        }
        else { // 3D
            ret.z(zeff);
        }
    }
    else if(symmetry() == CYLINDRICAL) {
        double r = sqrt(y*y + z*z);
        ret.x(xeff);
        ret.y(r);
        ret.z(0.0);
    }
    else { sl_assert(false, "norm_grid_coords", "bad symmetry"); }
    return ret;
}

bool PA::voxel_inside(int x, int y, int z) const
{
    return x >= 0 && x + 1 < nx() &&
           y >= 0 && y + 1 < ny() &&
          (nz() == 1 ? z == 0 : z >= 0 && z + 1 < nz());
}



bool PA::electrode(double x, double y, double z) const
{
    sl_assert(inside(x, y, z), "is_electrode", fail_point_(x, y, z));

    Vector3R norm = norm_grid_coords(x, y, z);

    int xi = int(norm.x());
    int yi = int(norm.y());
    int zi = int(norm.z());
    if(xi == x && yi == y && zi == z) {
        return electrode(xi, yi, zi);
    }

    bool res = solid(xi, yi, zi);
    return res;
}

// first-order linear interpolation
Vector3R PA::field(double x, double y, double z) const
{
    sl_assert(inside(x, y, z), "field", fail_point_(x, y, z));

    Vector3R ev;

    if(symmetry() == CYLINDRICAL) {
        double r = sqrt(y*y + z*z);

        // IMPROVE:is there a better way to handle boundary conditions?
        double xm = x - 0.5;
        double min_x = mirror_x() ? -(nx()-1) : 0;
        if(xm < min_x) xm = min_x;

        double xp = x + 0.5;
        if(xp > nx()-1) xp = nx()-1;

        double rm = r - 0.5;
        double min_r = -(ny()-1);
        if(rm < min_r) rm = min_r; // won't occur?

        double rp = r + 0.5;
        if(rp > ny()-1) rp = ny()-1;

        // FIX:Q:should the sampling be done before or after
        // applying cylindrical symmetry?
        double V2 = potential(xp, r,  0.0);
        double V1 = potential(xm, r,  0.0);
        double V4 = potential(x,  rp, 0.0);
        double V3 = potential(x,  rm, 0.0);

        //cout << xp << " " << V1 << " " << V2 << " " << V3 << " " << V4 << endl;

        double Ex = (V1 - V2) / (xp - xm);
        double Er = (V3 - V4) / (rp - rm);
        double Ey = Er * (r != 0 ? y/r : 1.0);
        double Ez = Er * (r != 0 ? z/r : 0.0);
        if(field_type() == MAGNETIC) {
            Ex *= ng();
            Ey *= ng();
            Ez *= ng();
            Er *= ng();
        }
        ev.set(Ex, Ey, Ez);
    }
    else { // planar
        // IMPROVE:is there a better way to handle boundary conditions?
        double xm = x - 0.5;
        double min_x = mirror_x() ? -(nx()-1) : 0;
        if(xm < min_x) xm = min_x;

        double xp = x + 0.5;
        if(xp > nx()-1) xp = nx()-1;

        double ym = y - 0.5;
        double min_y = mirror_y() ? -(ny()-1) : 0;
        if(ym < min_y) ym = min_y;

        double yp = y + 0.5;
        if(yp > ny()-1) yp = ny()-1;

        double zm = z - 0.5;
        double min_z = mirror_z() ? -(nz()-1) : 0;
        if(zm < min_z) zm = min_z;

        double zp = z + 0.5;
        if(zp > nz()-1) zp = nz()-1;
        double V2 = potential(xp, y,  z);
        double V1 = potential(xm, y,  z);
        double V4 = potential(x,  yp, z);
        double V3 = potential(x,  ym, z);
        double V5 = 0.0;
        double V6 = 0.0;
        if(nz() != 1) {
            V6 = potential(x, y, zp);
            V5 = potential(x, y, zm);
        }
        double Ex = (V1 - V2) / (xp - xm);
        double Ey = (V3 - V4) / (yp - ym);
        double Ez = (nz() == 1) ? 0.0 : (V5 - V6) / (zp - zm);

        if(field_type() == MAGNETIC) {
            Ex *= ng();
            Ey *= ng();
            Ez *= ng();
        }
        ev.set(Ex, Ey, Ez);
    }
    return ev;
}

void PA::field(int x, int y, int z, double ex, double ey, double ez, bool is_electrode)
{
    sl_assert(inside(x, y, z), "field", fail_point_(x,y,z));

      // perform numerical integration to solve the following for V:
      //
      //   E = - grad(V)
      //
      // This is done by the line integral:
      //
      //   V(x,y,z) = V(0,0,0) + line_integral_{C} E * n ds
      //
      // where C is an arbitrary path from (0,0,0) to (x,y,z).  For
      // each point (x,y,z), we actually do a weighted average of all
      // lattice paths (0,0,0) to (x,y,z) of length x+y+z.  In this
      // algorithm, the trapezoidal rule is used for the numerical
      // integration due to a nice algorithm requiring only O(1)
      // additional memory usage.
      //
      // Currently, V(0,0,0) is assumed to be zero.

    double field_x = ex;
    double field_y = ey;
    double field_z = ez;
    if(field_type() == MAGNETIC) {
        field_x /= ng();
        field_y /= ng();
        field_z /= ng();
    }

    //cout << "DEBUG" << to_string() << endl;
    if(x != nx() - 1) {
        point(x + 1, y, z, false,
                   raw_value(x + 1, y, z) - field_x);
    }
    if(y != ny() - 1) {
        point(x, y + 1, z, false,
                   raw_value(x, y + 1, z) - field_y);
    }
    if(z != nz() - 1) {
        point(x, y, z + 1, false,
                   raw_value(x, y, z + 1) - field_z);
    }

    if(x != 0 && y != 0 && z != 0) {
        double val =
            (potential(x-1, y,   z) +
             potential(x,   y-1, z) +
             potential(x,   y,   z-1)) / 3.0 +
            (raw_value(x,   y,   z) -
             field_x - field_y - field_z) / 6.0
        ;
        point(x, y, z, is_electrode, val);
    }
    else if(x != 0 && y != 0) { // z == 0
        double val = 
            (potential(x-1, y,   z) +
             potential(x,   y-1, z)) / 2.0 + 
            (raw_value(x,   y,   z) -
             field_x - field_y) / 4.0
        ;
        point(x, y, z, is_electrode, val);
    }
    else if(x != 0 && z != 0) { // y == 0
        double val = 
            (potential(x-1, y,   z) +
             potential(x,   y,   z-1)) / 2.0 + 
            (raw_value(x,   y,   z) -
             field_x - field_z) / 4.0
        ;
        point(x, y, z, is_electrode, val);
    }
    else if(y != 0 && z != 0) { // x == 0
        double val = 
            (potential(x,   y-1, z) +
             potential(x,   y,   z-1)) / 2.0 + 
            (raw_value(x,   y,   z) -
             field_y - field_z) / 4.0
        ;
        point(x, y, z, is_electrode, val);
    }
    else if(z != 0) { // x == 0 && y == 0
        double val = 
             potential(x,   y,   z-1) +
            (raw_value(x,   y,   z) -
             field_z) / 2.0
        ;
        point(x, y, z, is_electrode, val);
    }
    else if(y != 0) { // x == 0 && z == 0
        double val = 
             potential(x,   y-1, z) +
            (raw_value(x,   y,   z) -
             field_y) / 2.0
        ;
        point(x, y, z, is_electrode, val);
    }
    else if(x != 0) { // y == 0 && z == 0
        double val = 
             potential(x-1, y,   z) +
            (raw_value(x,   y,   z) -
             field_x) / 2.0
        ;
        point(x, y, z, is_electrode, val);
    }
    else { // x == 0 && y == 0 && z == 0
        point(x, y, z, is_electrode, 0);
    }
}


double PA::potential(double x, double y, double z) const
{
    sl_assert(inside(x, y, z), "potential", fail_point_(x, y, z));

    double xeff = (x < 0) ? -x : x;  // if mirroring
    double yeff = (y < 0) ? -y : y;
    double zeff = (z < 0) ? -z : z;

    double p = 0.0;
    if(symmetry() == PLANAR) {
        if(nz() == 1) { // 2D
            int xi = int(xeff);
            int yi = int(yeff);

            double wx = xeff - xi;
            double wy = yeff - yi;
            // note the checks on wx and wy to protect against cases where
            // xi + 1 == nx or yi + 1 == ny.
            p =
                (1-wx) * (1-wy) *              potential(xi, yi, 0) +
                   wx  * (1-wy) * ((wx != 0) ? potential(xi+1, yi,   0) : 0.0) +
                (1-wx) *    wy  * ((wy != 0) ? potential(xi,   yi+1, 0) : 0.0) +
                   wx  *    wy  * ((wx != 0 &&
                                    wy != 0) ? potential(xi+1, yi+1, 0) : 0.0)
            ;
        }
        else { // 3D
            int xi = int(xeff);
            int yi = int(yeff);
            int zi = int(zeff);

            double wx = xeff - xi;
            double wy = yeff - yi;
            double wz = zeff - zi;

            // note the checks on wx, wy, and wz to protect against cases where
            // xi + 1 == nx, yi + 1 == ny, or zi + 1 == nz.
            p =
                (1-wx)*(1-wy)*(1-wz)*potential(xi, yi, zi) +
                   wx *(1-wy)*(1-wz)*((wx != 0) ? potential(xi+1, yi,   zi) : 0.0) +
                (1-wx)*   wy *(1-wz)*((wy != 0) ? potential(xi,   yi+1, zi) : 0.0) +
                   wx *   wy *(1-wz)*((wx != 0 &&
                                       wy != 0) ? potential(xi+1, yi+1, zi) : 0.0) +

                (1-wx)*(1-wy)*   wz *((wz != 0) ? potential(xi, yi, zi+1) : 0.0) +
                   wx *(1-wy)*   wz *((wx != 0 &&
                                       wz != 0) ? potential(xi+1, yi,   zi+1) : 0.0) +
                (1-wx)*   wy *   wz *((wy != 0 &&
                                       wz != 0) ? potential(xi,   yi+1, zi+1) : 0.0) +
                   wx *   wy *   wz *((wx != 0 &&
                                       wy != 0 &&
                                       wz != 0) ? potential(xi+1, yi+1, zi+1) : 0.0)
            ;
        }
    }
    else if(symmetry() == CYLINDRICAL) {
        double r = sqrt(y*y + z*z);

        int xi = int(xeff);
        int ri = int(r);
        double wx = xeff - xi;
        double wr = r - ri;

        // note the checks on wx and wr to protect against cases where
        // xi + 1 == nx or ri + 1 == nr.
        p =
            (1-wx) * (1-wr) * potential(xi, ri, 0) +
               wx  * (1-wr) * ((wx != 0) ? potential(xi+1, ri,   0) : 0.0) +
            (1-wx) *    wr  * ((wr != 0) ? potential(xi,   ri+1, 0) : 0.0) +
               wx  *    wr  * ((wx != 0 &&
                                wr != 0) ? potential(xi+1, ri+1, 0) : 0.0)
        ;
    }
    else { sl_assert(false, "potential", "bad symmetry"); }

    return p;
}




bool PA::solid(int x, int y, int z) const
{
    sl_assert(voxel_inside(x, y, z), "solid", fail_point_(x, y, z));

    if(nz_ == 1) { // 2D planar or cylindrical
        bool is_electrode =
            electrode(x,   y,   z) &&
            electrode(x+1, y,   z) &&
            electrode(x,   y+1, z) &&
            electrode(x+1, y+1, z);
        return is_electrode;
    }
    else { // 3D
        bool is_electrode =
            electrode(x,   y,   z) &&
            electrode(x+1, y,   z) &&
            electrode(x,   y+1, z) &&
            electrode(x+1, y+1, z) &&
            electrode(x,   y,   z+1) &&
            electrode(x+1, y,   z+1) &&
            electrode(x,   y+1, z+1) &&
            electrode(x+1, y+1, z+1);
        return is_electrode;
    }
}


void PA::solid(int x, int y, int z, bool is_electrode, double potential)
{
    sl_assert(voxel_inside(x, y, z), "solid", fail_point_(x, y, z));

    double raw = 2*max_voltage() + potential;

    if(nz_ == 1) { // 2D planar or cylindrical
        ptrdiff_t n = PDIFF(y) * PDIFF(nx()) + PDIFF(x);
        points_[n]                       = raw;
        points_[n + 1]                   = raw;
        points_[n + PDIFF(nx())]         = raw;
        points_[n + PDIFF(nx()) + 1]     = raw;
    }
    else { // 3D
        ptrdiff_t n = pos_(x,y,z);
        points_[n]                       = raw;
        points_[n + 1]                   = raw;
        points_[n + PDIFF(nx())]         = raw;
        points_[n + PDIFF(nx()) + 1]     = raw;
        points_[n += PDIFF(ny()) * PDIFF(nx())] = raw;
        points_[n + 1]                   = raw;
        points_[n + PDIFF(nx())]         = raw;
        points_[n + PDIFF(nx()) + 1]     = raw;
    }

}



void PA::parse_ascii(std::istream& is, PATextHandler& handler)
{
    pat_->parse_ascii(is, handler);
}


std::string PA::symmetry_string(symmetry_t val)
{
    string s = (val == CYLINDRICAL) ? "cylindrical" : "planar";
    return s;
}

std::string PA::field_string(field_t val)
{
    string s = (val == ELECTROSTATIC) ? "electrostatic" : "magnetic";
    return s;
}


void PA::create_points_()
{
    destroy_points_();
    ptrdiff_t size = num_points();
    points_ = reinterpret_cast<double*>(allocator_->malloc(sizeof(double) * size));
    if(points_ == NULL) {
         stringstream ss;
         ss << "Memory allocation failed for point array (" << nx()
            << "," << ny() << "," << nz() << ").";
         throw ss.str();
    }
    memset(reinterpret_cast<char*>(points_), 0, size*sizeof(double)); // note: clear
}

void PA::destroy_points_()
{
    if(points_ != NULL) {
        allocator_->free(points_);
        points_ = NULL;
    }
}

void PA::max_voltage(double val) {
    sl_assert(check_max_voltage(val), "max_voltage", error());

    const ptrdiff_t npoints = num_points();

    double old_max_voltage = max_voltage();
    double diff = -2 * max_voltage() + 2 * val;

    max_voltage_ = val;
    for (ptrdiff_t n=0; n<npoints; n++) {
        if (points_[n] > old_max_voltage) {
            points_[n] += diff;
        }
    }
}

bool PA::inside_cylindrical_(double x, double r) const
{
    sl_assert(symmetry() == CYLINDRICAL,
              "inside_cylindrical", "symmetry not cylindrical");
    bool yes = (
        (x >= 0.0) ? (x <= nx()-1) :
        mirror_x() ? (-x <= nx()-1) :
        false
    ) && (r <= ny() - 1);
    return yes;
}


void PA::load_ascii_(istream& is)
{
    destroy_points_();
    MyTextHandler_ handler(this);
    parse_ascii(is, handler);
}

void PA::load_binary_(istream& is)
{
    destroy_points_();

    PAHeader header;
    if (!is.read(reinterpret_cast<char*>(&header.mode_), sizeof(int))) {
        stringstream ss;
        ss << "Could not read header from file";
        throw ss.str();
    }
    check_mode(header.mode_);

    if(!is.read(reinterpret_cast<char*>(&header)+sizeof(int),
          (header.mode_ == -1) ? sizeof(header)-sizeof(int)-sizeof(double)*3 :
                                 sizeof(header)-sizeof(int)
    )) {
        stringstream ss;
        ss << "Could not read header from file";
        throw ss.str();
    }

    bool ok = check(PAArgs().
        mode        (header.mode_).
        field_type  (header.field_type()).
        symmetry    (header.symmetry()).
        max_voltage (header.max_voltage_).
        nx          (header.nx_).
        ny          (header.ny_).
        nz          (header.nz_).
        mirror_x    (header.mirror_x()).
        mirror_y    (header.mirror_y()).
        mirror_z    (header.mirror_z()).
        ng          (header.ng()).
        dx_mm       (header.dx_mm_).
        dy_mm       (header.dy_mm_).
        dz_mm       (header.dz_mm_)
    );

    if(!ok)
        throw string(error());

    mode_        = header.mode_;
    field_type_  = header.field_type();
    symmetry_    = header.symmetry();
    max_voltage_ = header.max_voltage_;
    nx_          = header.nx_;
    ny_          = header.ny_;
    nz_          = header.nz_;
    mirror_x_    = header.mirror_x();
    mirror_y_    = header.mirror_y();
    mirror_z_    = header.mirror_z();
    ng_          = header.ng();
    dx_mm_       = header.dx_mm_;
    dy_mm_       = header.dy_mm_;
    dz_mm_       = header.dz_mm_;
    fast_adjustable_ = false; // default


    if(enable_points_) {
        points_ = reinterpret_cast<double*>(allocator_->malloc(sizeof(double) * num_points()));
        if(points_ == NULL) {
             stringstream ss;
             ss << "Memory allocation failed for point array (" << nx()
                << "," << ny() << "," << nz() << ").";
             throw ss.str();
        }

        ptrdiff_t chunklen = sizeof(double) * PDIFF(nx()) * PDIFF(ny());
        for(int z=0; z<nz(); ++z) {
            is.read(reinterpret_cast<char*>(points_) + PDIFF(z) * chunklen, chunklen);
            if(is.fail()) {
                throw string("Failed reading points from potential array");
            }
            if(pat_->status_ != NULL)
                pat_->status_->set_percent_complete(int(z * 100.0 / nz()));
            //improve:allow cancel?
        }
    } // end if enable_points
}


void PA::save_ascii_(std::ostream& os, const PAFormat& opt)
{
    os.precision(16);

    os
<< "# ASCII text representation of a SIMION PA file." << endl
<< "begin_potential_array" << endl;

    if(opt.enable_header()) {

    os
<< "begin_header" << endl
<< "    mode " << mode() << endl
<< "    symmetry " << symmetry_string(symmetry()) << endl
<< "    max_voltage " << max_voltage() << endl
<< "    nx " << nx() << endl
<< "    ny " << ny() << endl
<< "    nz " << nz() << endl
<< "    mirror_x " << (!!mirror_x()) << endl
<< "    mirror_y " << (!!mirror_y()) << endl
<< "    mirror_z " << (!!mirror_z()) << endl
<< "    field_type " << field_string(field_type()) << endl
<< "    ng " << ng() << endl;
    if (mode() <= -2) os
<< "    dx_mm " << dx_mm() << endl
<< "    dy_mm " << dy_mm() << endl
<< "    dz_mm " << dz_mm() << endl ;

    os
<< "    fast_adjustable " << fast_adjustable() << endl
<< "    data_format"
<< (opt.enable_coords() ? " x y z" : "")
<< " is_electrode"
<< ((opt.values() == PAFormat::POTENTIAL) ?
    " potential" : " field_x field_y field_z")
<< endl
<< "end_header" << endl;

    }

    if(opt.enable_data()) {

    // note: output in row-major order:
    //   double points[nz][ny][nz]
    os
<< "begin_points" << endl;

    double dx = opt.dx();

    for(double z=0; z<=nz()-1; z += dx) {
        for(double y=0; y<=ny()-1; y += dx) {
            for(double x=0; x<=nx()-1; x += dx) {
                if(opt.enable_coords())
                    os
<< x << " " << y << " " << z << " ";
                os
<< electrode(x, y, z) << " ";
                if(opt.values() == PAFormat::POTENTIAL)
                    os
<< potential(x, y, z) << endl;
                else { // field
                    Vector3R v = field(x, y, z);
                    os
<< v.x() << " " << v.y() << " " << v.z() << endl;
                }
            }
        }
        if(pat_->status_ != NULL) {
            int percent = int(z * 100.0 / nz());
            pat_->status_->set_percent_complete(percent);
        }
    }

    os
<< "end_points" << endl;

    }

    os
<< "end_potential_array" << endl;

}


void PA::save_binary_(std::ostream& os, const PAFormat& opt)
{
    sl_assert(enable_points_, "save", "enable_points must be enabled.");

    PAHeader header(
        mode(),
        field_type(),
        symmetry(),
        max_voltage(),
        nx(),
        ny(),
        nz(),
        mirror_x(),
        mirror_y(),
        mirror_z(),
        ng(),
        dx_mm(),
        dy_mm(),
        dz_mm()
    );

    if (mode() == -1)
        os.write(reinterpret_cast<char*>(&header), sizeof(header)-sizeof(double)*3);
    else
        os.write(reinterpret_cast<char*>(&header), sizeof(header));

    ptrdiff_t len = num_points();
    ptrdiff_t chunklen = PDIFF(nx()) * PDIFF(ny()) * sizeof(double);
    for(int n = 0; n < nz(); n++) {
        os.write(reinterpret_cast<char*>(points_) + PDIFF(n) * chunklen, chunklen);
        if(pat_->status_ != NULL) {
            pat_->status_->set_percent_complete(int(double(n)*100.0/nz()));
        }
    }

    // record stats in PA0 file.  WARNING: assumes SIMION 7.0 fast adjust limits
    if(pasharp_ != NULL) {
        sl_assert(pasharp_->nx() == nx() && pasharp_->ny() == ny()
                  && pasharp_->nz() == nz(), "save",
                  "PA# dimensions does not match PA0 dimensions");

        ptrdiff_t n;
        // records first index of electrodes.
        int first_idx[31];
        for(n=0; n<=30; n++) first_idx[n] = -1;

        for(n=0; n<len; n++) {
            double fval = pasharp_->points_[n];
            if(fval >= 2 * pasharp_->max_voltage()) { // electrode
                fval -= 2 * pasharp_->max_voltage();

                int ival = (int)fval;
                if(ival == fval && ival >= 1 && ival <= 30) { // fast adjustable
                    if(first_idx[ival] == -1) {
                        //cout << ival << " " << n << endl;
                        first_idx[ival] = static_cast<int>(n); // WARNING: assumes not 64-bit sizes
                    }
                }
                else if(first_idx[0] == -1) { // fast scalable
                    first_idx[0] = static_cast<int>(n); // WARNING: assumes not 64-bit sizes
                }
            }
        }

        int i;
        double d;

        int num_electrodes = (first_idx[0] != -1) ? 1 : 0;
        for(n=1; n<=30; n++) {
            if(first_idx[n] != -1)
                num_electrodes++;
        }
 
        os.write(reinterpret_cast<char*>(&num_electrodes), sizeof(int));
        d = 10000.0;
        os.write(reinterpret_cast<char*>(&d), sizeof(double));
        for(n=0; n<=30; n++)
            os.write(reinterpret_cast<char*>(&first_idx[n]), sizeof(int));
        i = -1;
        os.write(reinterpret_cast<char*>(&i), sizeof(int));
    }

    if(!os)
        throw string("Failed writing potential array header.");
}



bool PA::check(const PAArgs& args_orig)
{
#   define SL_CHECK(name) \
        if(args.name ## _defined() && !check_ ## name(args.name())) return false;
#   define SL_EQUAL(name, value) \
        (args.name ## _defined() && args.name() == value)
#   define SL_NOTEQUAL(name, value) \
        (args.name ## _defined() && args.name() != value)
#   define SL_TRUE(name) \
        (args.name ## _defined() && args.name())
#   define SL_FALSE(name) \
        (args.name ## _defined() && !args.name())

    PAArgs args = args_orig;

    SL_CHECK(mode)
    SL_CHECK(symmetry)
    SL_CHECK(max_voltage)
    SL_CHECK(field_type)
    SL_CHECK(ng)
    SL_CHECK(nx)
    SL_CHECK(ny)
    SL_CHECK(nz)
    SL_CHECK(dx_mm)
    SL_CHECK(dy_mm)
    SL_CHECK(dz_mm)

    if(args.nx_defined() && !check_size(args.nx(), args.ny(), args.nz()))
        return false;

    // removed: mirror alias

    if(SL_EQUAL(symmetry, CYLINDRICAL) && SL_FALSE(mirror_y))
        return fail_string_(
            "y mirroring must be enabled under cylindrical symmetry.");

    if(SL_EQUAL(symmetry, CYLINDRICAL) && SL_NOTEQUAL(nz, 1))
        return fail_string_(
            "nz (" + str(args.nz()) + ") must be 1 under cylindrical symmetry.");

    if(SL_TRUE(mirror_z) && SL_EQUAL(nz, 1))
        return fail_string_(
            "nz (" + str(args.nz()) + ") cannot be 1 under z mirroring.");

#   undef SL_CHECK
#   undef SL_EQUAL
#   undef SL_NOTEQUAL
#   undef SL_TRUE
#   undef SL_FALSE

    return true;
}

bool PA::fail_string_(const std::string& str) {
    error_ = str;
    return false;
}

bool PA::fail_mode_(int val) {
    error_ = (string)"Mode (" + str(val) + ") is out of range.";
    return false;
}

bool PA::fail_max_voltage_(double val) {
    error_ = (string)"Max voltage (" + str(val) + ") is out of range.";
    return false;
}

bool PA::fail_nx1_(int val) {
    error_ = (string)"nx value (" + str(val) + ") must be no less than 3.";
    return false;
}

bool PA::fail_nx2_(int val) {
    error_ = (string)"nx value (" + str(val) + ") must be no greater than 90000.";
    return false;
}

bool PA::fail_ny1_(int val) {
    error_ = (string)"ny value (" + str(val) + ") must be no less than 3.";
    return false;
}

bool PA::fail_ny2_(int val) {
    error_ = (string)"ny value (" + str(val) + ") must be no greater than 90000.";
    return false;
}

bool PA::fail_nz1_(int val) {
    error_ = (string)"nz value (" + str(val) + ") must be no less than 1.";
    return false;
}

bool PA::fail_nz2_(int val) {
    error_ = (string)"nz value (" + str(val) + ") must be no greater than 90000.";
    return false;
}

bool PA::fail_ng_(double val) {
    error_ = (string)"Magnetic scaling factor (" + str(val) +\
             ") must be no less than 1.";
    return false;
}

bool PA::fail_d_mm_(double val, char axis, int direction) {
    if (direction == -1)
        error_ = (string)"d" + string(1,axis) + (string)"_mm value ("
                 + str(val) + ") must be no less than 1e-6.";
    else
        error_ = (string)"d" + string(1,axis) + (string)"_mm value (" + str(val)
                 + ") must be no greater than 900.0.";
    return false;
}

bool PA::fail_field_type_(field_t val) {
    error_ = (string)"Field type (" + str(int(val)) +
             ") must be ELECTROSTATIC or MAGNETIC.";
    return false;
}

bool PA::fail_symmetry_(symmetry_t val) {
    error_ = "Symmetry (" + str(int(val)) + ") must be PLANAR or CYLINDRICAL.";
    return false;
}

bool PA::fail_size_(int nx, int ny, int nz) {
    error_ = (string) "(" + str(nx) + "," + str(ny) + "," + str(nz) + 
        ") exceeds " + str(MAX_POINTS) + " points in " + (MEMORY_64BIT ? "64-bit" : "32-bit") + " SIMION.";
    return false;
}


// IMPLEMENTATION PATextImpl_

void PATextImpl_::parse_exception(const std::string& str)
{
    stringstream ss;
    ss << "Error in PATXT file: " << str << " on line #" << linenum_
       << " near \"" << tok.str << "\"" << endl;
    throw ss.str();
}

void PATextImpl_::eat_line()
{
    while(1) {
        int cnext = is->peek();
        if(cnext == '\n' || cnext == '\r' || cnext == -1)
            break;
        is->get();
    }
}

void PATextImpl_::eat_whitespace()
{
    while(1) {  // ignore initial whitespace
        int cnext = is->peek();
        if(cnext != ' ' && cnext != '\t')
            break;
        is->get();
    }
}

void PATextImpl_::read_word(const char* term_chars)
{
    int pos = 0;
    while(1) {
        int cnext = is->peek();
        if(cnext == -1)
            break;
        if(strchr(term_chars, cnext) != NULL)
            break;
        if(pos >= 255) {
            tok.str[255] = '\0';
            parse_exception("Token too long");
        }
        tok.str[pos++] = cnext;
        is->get();
        cnext = is->peek();
    }
    tok.str[pos] = '\0';
    //cout << "DEBUG:token_word[" << tok.str << "]" << endl;
}


void PATextImpl_::next_token()
{
    tok.type = T_NULL;

    eat_whitespace();

    int cnext = is->peek();

    if(cnext == '#') { // comment
        eat_line();
        cnext = is->peek();
    }

    if(cnext == '\n' || cnext == '\r') {
        tok.type = T_EOL;
        while(1) {
            cnext = is->peek();
            if(cnext == '\r' || cnext == '\n')
                is->get();
            else
                break;
        }
    }
    else if(cnext == -1) {
        if(eof_found_) {
            tok.type = T_NULL;
        }
        else {
            tok.type = T_EOL; // for consistency, insert EOL before EOF
                              //(e.g. if EOL not exist)
            eof_found_ = true;
        }
    }
    else {
        read_word("# \r\n\t");

        if(isalpha(tok.str[0])) {
            if(strcmp(tok.str, "begin_potential_array") == 0)
                tok.type = T_BEGIN_POTENTIAL_ARRAY;
            else if(strcmp(tok.str, "begin_header") == 0)
                tok.type = T_BEGIN_HEADER;
            else if(strcmp(tok.str, "mode") == 0)
                tok.type = T_MODE;
            else if(strcmp(tok.str, "symmetry") == 0)
                tok.type = T_SYMMETRY;
            else if(strcmp(tok.str, "max_voltage") == 0)
                tok.type = T_MAX_VOLTAGE;
            else if(strcmp(tok.str, "nx") == 0)
                tok.type = T_NX;
            else if(strcmp(tok.str, "ny") == 0)
                tok.type = T_NY;
            else if(strcmp(tok.str, "nz") == 0)
                tok.type = T_NZ;
            else if(strcmp(tok.str, "mirror_x") == 0)
                tok.type = T_MIRROR_X;
            else if(strcmp(tok.str, "mirror_y") == 0)
                tok.type = T_MIRROR_Y;
            else if(strcmp(tok.str, "mirror_z") == 0)
                tok.type = T_MIRROR_Z;
            else if(strcmp(tok.str, "field_type") == 0)
                tok.type = T_FIELD_TYPE;
            else if(strcmp(tok.str, "ng") == 0)
                tok.type = T_NG;
            else if(strcmp(tok.str, "dx_mm") == 0)
                tok.type = T_DX_MM;
            else if(strcmp(tok.str, "dy_mm") == 0)
                tok.type = T_DY_MM;
            else if(strcmp(tok.str, "dz_mm") == 0)
                tok.type = T_DZ_MM;
            else if(strcmp(tok.str, "fast_adjustable") == 0)
                tok.type = T_FAST_ADJUSTABLE;
            else if(strcmp(tok.str, "data_format") == 0)
                tok.type = T_DATA_FORMAT;
            else if(strcmp(tok.str, "end_header") == 0)
                tok.type = T_END_HEADER;
            else if(strcmp(tok.str, "begin_points") == 0)
                tok.type = T_BEGIN_POINTS;
            else if(strcmp(tok.str, "end_points") == 0)
                tok.type = T_END_POINTS;
            else if(strcmp(tok.str, "end_potential_array") == 0)
                tok.type = T_END_POTENTIAL_ARRAY;
            else if(strcmp(tok.str, "planar") == 0)
                tok.type = T_PLANAR;
            else if(strcmp(tok.str, "cylindrical") == 0)
                tok.type = T_CYLINDRICAL;
            else if(strcmp(tok.str, "electrostatic") == 0)
                tok.type = T_ELECTROSTATIC;
            else if(strcmp(tok.str, "magnetic") == 0)
                tok.type = T_MAGNETIC;
            else if(strcmp(tok.str, "x") == 0)
                tok.type = T_X;
            else if(strcmp(tok.str, "y") == 0)
                tok.type = T_Y;
            else if(strcmp(tok.str, "z") == 0)
                tok.type = T_Z;
            else if(strcmp(tok.str, "is_electrode") == 0)
                tok.type = T_IS_ELECTRODE;
            else if(strcmp(tok.str, "potential") == 0)
                tok.type = T_POTENTIAL;
            else if(strcmp(tok.str, "raw_value") == 0)
                tok.type = T_RAW_VALUE;
            else if(strcmp(tok.str, "field_x") == 0)
                tok.type = T_FIELD_X;
            else if(strcmp(tok.str, "field_y") == 0)
                tok.type = T_FIELD_Y;
            else if(strcmp(tok.str, "field_z") == 0)
                tok.type = T_FIELD_Z;

            else {
                parse_exception("Unrecognized keyword");
            }
        }
        else if(isdigit(tok.str[0]) || tok.str[0] == '+' || tok.str[0] == '-' || tok.str[0] == '.') {
            char c;
            int count = sscanf(tok.str, "%f%c", static_cast<float*>(&tok.fval), &c);
            if(count != 1)
                parse_exception("Bad number format");
            tok.type = T_NUMBER;
            //cout << "DEBUG:TOKEN:T_NUMBER:" << tok.str << " " << tok.fval << endl;
            //IMPROVE:what if integer type with overflow?
        }
        else {
            parse_exception("Unexpected token.");
        }
    }

}


void PATextImpl_::parse_header()
{
    parse_nls();

    if(tok.type != T_BEGIN_HEADER)
        parse_exception(string("Expected 'begin_header'"));
    next_token();

    parse_nl();


    while(1) {
        if(tok.type == T_MODE) {
            next_token();
            if(tok.type != T_NUMBER)
                parse_exception("Expected number.");
            header_.mode((int)tok.fval);
            if(!pa_->check_mode(header_.mode()))
                parse_exception("Mode out of range.");
            // IMPROVE:Q: allow duplicates to override each other?
            fields_set_ |= F_MODE;
            next_token();
        }
        else if(tok.type == T_SYMMETRY) {
            next_token();
            if(tok.type != T_PLANAR && tok.type != T_CYLINDRICAL)
                parse_exception("Expected 'planar' or 'cylindrical'.");
            header_.symmetry((tok.type == T_PLANAR) ? PLANAR : CYLINDRICAL);
            fields_set_ |= F_SYMMETRY;
            next_token();
        }
        else if(tok.type == T_MAX_VOLTAGE) {
            next_token();
            if(tok.type != T_NUMBER)
                parse_exception("Expected number.");
            header_.max_voltage(tok.fval);
            if(!pa_->check_max_voltage(header_.max_voltage()))
                parse_exception("Max voltage out of range");
            fields_set_ |= F_MAX_VOLTAGE;
            next_token();
        }
        else if(tok.type == T_NX) {
            next_token();
            if(tok.type != T_NUMBER)
                parse_exception("Expected number.");
            header_.nx((int)tok.fval);
            if(!pa_->check_nx(header_.nx()))
                parse_exception("nx out of range.");
            fields_set_ |= F_NX;
            next_token();
        }
        else if(tok.type == T_NY) {
            next_token();
            if(tok.type != T_NUMBER)
                parse_exception("Expected number.");
            header_.ny((int)tok.fval);
            if(!pa_->check_ny(header_.ny()))
                parse_exception("ny out of range.");
            fields_set_ |= F_NY;
            next_token();
        }
        else if(tok.type == T_NZ) {
            next_token();
            if(tok.type != T_NUMBER)
                parse_exception("Expected number.");
            header_.nz((int)tok.fval);
            if(!pa_->check_nz(header_.nz()))
                parse_exception("nz out of range.");
            fields_set_ |= F_NZ;
            next_token();
        }
        else if(tok.type == T_MIRROR_X) {
            next_token();
            if(tok.type != T_NUMBER)
                parse_exception("Expected number.");
            if(tok.fval != 0 && tok.fval != 1)
                parse_exception("mirror_x should be 0 or 1");
            header_.mirror_x(tok.fval != 0);
            fields_set_ |= F_MIRROR_X;
            next_token();
        }
        else if(tok.type == T_MIRROR_Y) {
            next_token();
            if(tok.type != T_NUMBER)
                parse_exception("Expected number.");
            if(tok.fval != 0 && tok.fval != 1)
                parse_exception("mirror_y should be 0 or 1");
            header_.mirror_y(tok.fval != 0);
            fields_set_ |= F_MIRROR_Y;
            next_token();
        }
        else if(tok.type == T_MIRROR_Z) {
            next_token();
            if(tok.type != T_NUMBER)
                parse_exception("Expected number.");
            if(tok.fval != 0 && tok.fval != 1)
                parse_exception("mirror_z should be 0 or 1");
            header_.mirror_z(tok.fval != 0);
            fields_set_ |= F_MIRROR_Z;
            next_token();
        }
        else if(tok.type == T_FIELD_TYPE) {
            next_token();
            if(tok.type != T_ELECTROSTATIC && tok.type != T_MAGNETIC)
                parse_exception("Expected 'electrostatic' or 'magnetic'.");
            header_.field_type(tok.type == T_ELECTROSTATIC ? ELECTROSTATIC : MAGNETIC);
            fields_set_ |= F_FIELD;
            next_token();
        }
        else if(tok.type == T_NG) {
            next_token();
            if(tok.type != T_NUMBER)
                parse_exception("Expected number.");
            header_.ng(tok.fval);
            if(!pa_->check_ng(header_.ng()))
                parse_exception("ng out of range.");
            fields_set_ |= F_NG;
            next_token();
        }
        else if(tok.type == T_DX_MM) {
            next_token();
            if(tok.type != T_NUMBER)
                parse_exception("Expected number.");
            header_.dx_mm(tok.fval);
            if(!pa_->check_dx_mm(header_.dx_mm()))
                parse_exception("dx_mm out of range.");
            fields_set_ |= F_DX_MM;
            next_token();
        }
        else if(tok.type == T_DY_MM) {
            next_token();
            if(tok.type != T_NUMBER)
                parse_exception("Expected number.");
            header_.dy_mm(tok.fval);
            if(!pa_->check_dy_mm(header_.dy_mm()))
                parse_exception("dy_mm out of range.");
            fields_set_ |= F_DY_MM;
            next_token();
        }
        else if(tok.type == T_DZ_MM) {
            next_token();
            if(tok.type != T_NUMBER)
                parse_exception("Expected number.");
            header_.dz_mm(tok.fval);
            if(!pa_->check_dz_mm(header_.dz_mm()))
                parse_exception("dz_mm out of range.");
            fields_set_ |= F_DZ_MM;
            next_token();
        }
        else if(tok.type == T_FAST_ADJUSTABLE) {
            next_token();
            if(tok.type != T_NUMBER)
                parse_exception("Expected number.");
            int val = (int)tok.fval;
            if(val != 0 && val != 1)
                parse_exception("fast_adjustable value out of range.");
            header_.fast_adjustable(val != 0);
            fields_set_ |= F_FAST_ADJUSTABLE;
            next_token();
        }
        else if(tok.type == T_DATA_FORMAT) {
            next_token();
            int column_num = 0;
            while(1) {
                const char* names[] = {"x", "y", "z", "is_electrode", "potential",
                    "raw_value", "field_x", "field_y", "field_z"};

                if(tok.type == T_X || tok.type == T_Y || tok.type == T_Z
                   || tok.type == T_IS_ELECTRODE || tok.type == T_POTENTIAL
                   || tok.type == T_RAW_VALUE
                   || tok.type == T_FIELD_X || tok.type == T_FIELD_Y
                   || tok.type == T_FIELD_Z)
                {
                    int idx = tok.type - T_X;
                    PATextHeader::point_column_t col = (PATextHeader::point_column_t)(1 << idx);
                    if(header_.is_column_enabled(col))
                        parse_exception(string(names[idx]) + " duplicated in list");
                    header_.enable_column(column_num++, col);

                    next_token();
                }
                else if(tok.type == T_EOL)
                    break;
                else
                    parse_exception("Unexpected token");
            }

            if(header_.is_column_enabled(PATextHeader::PI_FIELD)) {
                if(header_.is_column_enabled(PATextHeader::PI_POTENTIAL))
                    parse_exception("'field' and 'potential' can not both be defined in data_format");
                if(header_.is_column_enabled(PATextHeader::PI_RAW_VALUE))
                    parse_exception("'field' and 'raw_value' can not both be defined in data_format");

            }
            else if(header_.is_column_enabled(PATextHeader::PI_POTENTIAL)) {
                if(header_.is_column_enabled(PATextHeader::PI_RAW_VALUE))
                    parse_exception("'field' and 'raw_value' can not both be defined in data_format");
            }

        }
        else if(tok.type == T_END_HEADER) {
            break;
        }
        else if(tok.type == T_EOL) {
        }
        else {
            parse_exception("Unexpected token");
        }

        parse_nl();
    }

    if(tok.type == T_END_HEADER) {
        next_token();
        
        parse_nl();
    }

    handler->process_header(header_);

}

void PATextImpl_::parse_data()
{
    parse_nls();

    if(tok.type != T_BEGIN_POINTS)
        parse_exception("Expected 'begin_points'");
    next_token();

    parse_nl();

    int x = -1;
    int y = 0;
    int z = 0;

    ptrdiff_t point_count = 0;
    while(1) {
        parse_nls();
        if(tok.type != T_NUMBER)
            break;

        PAPointInfo info;
        if(! header_.is_column_enabled(PATextHeader::PI_XYZ)) {
            if(x < header_.nx() - 1)
              x++;
            else if(y < header_.ny() - 1) {
              y++; x = 0;
            }
            else if(z < header_.nz() - 1) {
              z++; y = 0; x = 0;
            }
            else 
                parse_exception("More than the expected number of data points found in file.");
            info.x(x);
            info.y(y);
            info.z(z);
            //cout << x << " " << y << " " << z << endl;
        }

        info.enabled(header_.enabled_columns());


        for(int n=0; n<(int)header_.column_count(); n++) {
            if(tok.type != T_NUMBER)
                parse_exception("Expected number.");
            switch(header_.column(n)) {
            case PATextHeader::PI_X:
                //cout << "info:x=" << (int)tok.fval << endl;
                info.x((int)tok.fval); break;
            case PATextHeader::PI_Y:
                info.y((int)tok.fval); break;
            case PATextHeader::PI_Z:
                info.z((int)tok.fval); break;
            case PATextHeader::PI_IS_ELECTRODE:
                info.is_electrode(tok.fval != 0); break;
            case PATextHeader::PI_POTENTIAL:
                info.potential(tok.fval); break;
            case PATextHeader::PI_RAW_VALUE:
                info.raw_value(tok.fval); break;
            case PATextHeader::PI_FIELD_X:
                info.field_x(tok.fval); break;
            case PATextHeader::PI_FIELD_Y:
                info.field_y(tok.fval); break;
            case PATextHeader::PI_FIELD_Z:
                info.field_z(tok.fval); break;
            // prevent compiler warning
            case PATextHeader::PI_FIELD:
            case PATextHeader::PI_XYZ:
                break;
            default:
                //cout << "DEBUG:" << header_.column(n) << endl;
                sl_assert(false, "parse_data", "internal error");
            }
            next_token();
        }
        parse_nl();

        if(!( (info.x() >= 0 && info.x() < header_.nx() &&
               info.y() >= 0 && info.y() < header_.ny() &&
               info.z() >= 0 && info.z() < header_.nz())
            ))
        {
            parse_exception("Point outside of array.");
        }

        handler->process_point(info);
        point_count++;

        if(status_ != NULL && point_count % 500 == 0) {
            ptrdiff_t num_points =
                static_cast<ptrdiff_t>(header_.nx()) *
                static_cast<ptrdiff_t>(header_.ny()) *
                static_cast<ptrdiff_t>(header_.nz()) ;
            status_->set_percent_complete(
                (int)(double(point_count)*100.0 / num_points));
        }
    }

    if(tok.type != T_END_POINTS)
        parse_exception("Expected 'end_points'");
    next_token();

    if(! header_.is_column_enabled(PATextHeader::PI_XYZ)) {
        if(x != header_.nx()-1 || y != header_.ny()-1 || z != header_.nz()-1)
            parse_exception("Missing data points in data file.");
    }

    parse_nl();
}


// exactly one new line
void PATextImpl_::parse_nl()
{
    if(tok.type != T_EOL)
        parse_exception("Expected new line");
    next_token();
    linenum_++;
}

// zero or more new lines
void PATextImpl_::parse_nls()
{
    while(tok.type == T_EOL) {
        next_token();
        linenum_++;
    }
}


void PATextImpl_::parse_ascii(std::istream& is1, PATextHandler& handler1)
{
    is = &is1;
    handler = &handler1;
    linenum_ = 1;
    eof_found_ = false;
    header_ = PATextHeader();
    fields_set_ = 0;

    next_token();

    parse_nls();

    if(tok.type != T_BEGIN_POTENTIAL_ARRAY)
        parse_exception("Missing 'begin_potential_array'");
    next_token();

    parse_nl();

    parse_header();
    parse_data();

    if(tok.type != T_END_POTENTIAL_ARRAY)
        parse_exception("Missing 'end_potential_array'");
    next_token();

    parse_nls();

    if(tok.type != T_NULL)
        parse_exception("Extra token found after 'end_potential_array'");
}


// IMPLEMENTATION MyTextHandler_

void MyTextHandler_::process_header(const PATextHeader& header)
{
    pa_->set(header);
}
void MyTextHandler_::process_point(const PAPointInfo& info)
{
    if((info.enabled() & (PATextHeader::PI_FIELD_X|PATextHeader::PI_FIELD_Y|PATextHeader::PI_FIELD_Z)) != 0) {
        pa_->field(info.x(), info.y(), info.z(),
                   info.field_x(), info.field_y(), info.field_z(), info.is_electrode());
    } // if
    else if((info.enabled() & PATextHeader::PI_RAW_VALUE) != 0) {
        pa_->raw_value(info.x(), info.y(), info.z(), info.raw_value());
    }
    else {
        pa_->point(info.x(), info.y(), info.z(), info.is_electrode(), info.potential());
    }

    //cout << "DEBUG:point=" << pa_->potential(info.x(), info.y(), info.z()) << endl;
}


// IMPLEMENTATION PAPointInfo

std::string PAPointInfo::string() const
{
    stringstream ss;
    int idx = 0;
    ss << "pi[";
    if((enabled() & PATextHeader::PI_X) != 0)
        ss << (idx++ == 0 ? "" : ",") << "x=" << x();
    if((enabled() & PATextHeader::PI_Y) != 0)
        ss << (idx++ == 0 ? "" : ",") << "y=" << y();
    if((enabled() & PATextHeader::PI_Z) != 0)
        ss << (idx++ == 0 ? "" : ",") << "z=" << z();
    if((enabled() & PATextHeader::PI_IS_ELECTRODE) != 0)
        ss << (idx++ == 0 ? "" : ",") << "is_electrode=" << is_electrode();
    if((enabled() & PATextHeader::PI_POTENTIAL) != 0)
        ss << (idx++ == 0 ? "" : ",") << "potential=" << potential();
    if((enabled() & PATextHeader::PI_RAW_VALUE) != 0)
        ss << (idx++ == 0 ? "" : ",") << "raw_value=" << raw_value();
    if((enabled() & PATextHeader::PI_FIELD_X) != 0)
        ss << (idx++ == 0 ? "" : ",") << "field_x=" << field_x();
    if((enabled() & PATextHeader::PI_FIELD_Y) != 0)
        ss << (idx++ == 0 ? "" : ",") << "field_y=" << field_y();
    if((enabled() & PATextHeader::PI_FIELD_Z) != 0)
        ss << (idx++ == 0 ? "" : ",") << "field_z=" << field_z();
    ss << "]";
    return ss.str();
}


} // end namespace


