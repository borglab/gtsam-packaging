/* ----------------------------------------------------------------------------

 * GTSAM Copyright 2010, Georgia Tech Research Corporation, 
 * Atlanta, Georgia 30332-0415
 * All Rights Reserved
 * Authors: Frank Dellaert, et al. (see THANKS for the full author list)

 * See LICENSE for the license information

 * -------------------------------------------------------------------------- */

/**
 *  @file   GPSFactor.h
 *  @author Frank Dellaert
 *  @brief  Header file for GPS factor
 *  @date   January 22, 2014
 **/
#pragma once

#include <gtsam/nonlinear/NonlinearFactor.h>
#include <gtsam/geometry/Pose3.h>

namespace gtsam {

/**
 * Prior on position in a Cartesian frame.
 * Possibilities include:
 *   ENU: East-North-Up navigation frame at some local origin
 *   NED: North-East-Down navigation frame at some local origin
 *   ECEF: Earth-centered Earth-fixed, origin at Earth's center
 * See Farrell08book or e.g. http://www.dirsig.org/docs/new/coordinates.html
 * @addtogroup Navigation
 */
class GPSFactor: public NoiseModelFactor1<Pose3> {

private:

  typedef NoiseModelFactor1<Pose3> Base;

  Point3 nT_; ///< Position measurement in

public:

  /// shorthand for a smart pointer to a factor
  typedef boost::shared_ptr<GPSFactor> shared_ptr;

  /// Typedef to this class
  typedef GPSFactor This;

  /** default constructor - only use for serialization */
  GPSFactor() {
  }

  virtual ~GPSFactor() {
  }

  /**
   * @brief Constructor from a measurement in a Cartesian frame.
   * Use GeographicLib to convert from geographic (latitude and longitude) coordinates
   * @param key of the Pose3 variable that will be constrained
   * @param gpsIn measurement already in  coordinates
   * @param model Gaussian noise model
   */
  GPSFactor(Key key, const Point3& gpsIn, const SharedNoiseModel& model) :
      Base(model, key), nT_(gpsIn) {
  }

  /// @return a deep copy of this factor
  virtual gtsam::NonlinearFactor::shared_ptr clone() const {
    return boost::static_pointer_cast<gtsam::NonlinearFactor>(
        gtsam::NonlinearFactor::shared_ptr(new This(*this)));
  }

  /** implement functions needed for Testable */

  /** print */
  virtual void print(const std::string& s, const KeyFormatter& keyFormatter =
      DefaultKeyFormatter) const;

  /** equals */
  virtual bool equals(const NonlinearFactor& expected, double tol = 1e-9) const;

  /** implement functions needed to derive from Factor */

  /** vector of errors */
  Vector evaluateError(const Pose3& p,
      boost::optional<Matrix&> H = boost::none) const;

  inline const Point3 & measurementIn() const {
    return nT_;
  }

  /*
   *  Convenience funcion to estimate state at time t, given two GPS
   *  readings (in local NED Cartesian frame) bracketing t
   *  Assumes roll is zero, calculates yaw and pitch from NED1->NED2 vector.
   */
  static std::pair<Pose3, Vector3> EstimateState(double t1, const Point3& NED1,
      double t2, const Point3& NED2, double timestamp);

private:

  /** Serialization function */
  friend class boost::serialization::access;
  template<class ARCHIVE>
  void serialize(ARCHIVE & ar, const unsigned int version) {
    ar
        & boost::serialization::make_nvp("NoiseModelFactor1",
            boost::serialization::base_object<Base>(*this));
    ar & BOOST_SERIALIZATION_NVP(nT_);
  }
};

} /// namespace gtsam
