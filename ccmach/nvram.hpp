//
//  nvram_map.h
//  ccmach
//
//  Created by Landon Fuller on 1/1/16.
//  Copyright (c) 2016 Landon Fuller. All rights reserved.
//

#include <string>
#include <unistd.h>
#include <err.h>
#include <sysexits.h>
#include <vector>
#include <unordered_map>
#include <unordered_set>

#include "record_type.hpp"

#include <Foundation/Foundation.h>

extern "C" {
#include "bcmsrom_tbl.h"
}

using namespace std;
using namespace pl;

namespace nvram {

/** NVRAM variable data types */
typedef enum {
	BHND_T_UINT8,	/**< unsigned 8 bit integer */
	BHND_T_UINT16,	/**< unsigned 16 bit integer */
	BHND_T_UINT32,	/**< unsigned 32 bit integer */

	BHND_T_INT8,	/**< signed 8 bit integer */
	BHND_T_INT16,	/**< signed 16 bit integer */
	BHND_T_INT32,	/**< signed 32 bit integer */

	BHND_T_CHAR,	/**< ascii char */
} prop_type;

prop_type prop_type_widen (prop_type operand);
bool prop_type_compat (prop_type lhs, prop_type rhs);
 
/** NVRAM variable string representations */
typedef enum {
	SFMT_HEX,		/**< hex format */
	SFMT_DECIMAL,		/**< decimal format */
	SFMT_MACADDR,		/**< mac address (canonical form, hex octets,
					 seperated with ':') */
	SFMT_CCODE,		/**< count code format (2-3 ASCII chars, or hex string) */
	SFMT_LEDDC,		/**< LED PWM duty-cycle (2 bytes -- on/off) */
} str_fmt;

/** NVRAM variable flags */
enum {
	FLAG_MFGINT	= (1<<1),	/**< mfg-internal variable; should not be externally visible */
	FLAG_NOALL1	= (1<<2)	/**< ignore variable if its value has all bits set. */
};

/** SPROM revision compatibility declaration */
class compat_range {
public:
	static const uint8_t MAX_SPROMREV = 31;	/**< maximum supported SPROM revision */

	PL_RECORD_FIELDS(compat_range,
		(uint8_t, first),	/**< first compatible SPROM revision */
		(uint8_t, last)		/**< last compatible SPROM revision, or BHND_SPROMREV_MAX */
	);

public:
	static compat_range from_revmask (uint32_t revmask) {
		if (revmask == 0)
			return compat_range(0, 0);

		uint8_t first_ver = __builtin_ctz(revmask);
		uint8_t last_ver = MAX_SPROMREV - __builtin_clz(revmask);
		for (uint8_t i = first_ver; i <= last_ver; i++)
			assert(revmask & (1 << i));
		
		return compat_range(first_ver, last_ver);
	}
	
	compat_range merge (const compat_range &other) const {
		return from_revmask(other.to_revmask() | to_revmask());
	}
	
	uint32_t to_revmask (void) const {
		uint32_t ret = 0;
		for (uint8_t i = _first; i <= _last; i++) {
			ret |= (1 << i);
		}
		assert(from_revmask(ret) == *this);
		return (ret);
	}

	string description () const {
		if (last() == MAX_SPROMREV)
			return [NSString stringWithFormat: @">= %u", first()].UTF8String;
		else if (first() == last())
			return [NSString stringWithFormat: @"%u", first()].UTF8String;
		else
			return [NSString stringWithFormat: @"%u-%u", first(), last()].UTF8String;
	}
};

	
/** SPROM value segment descriptor */
class value_seg {
	PL_RECORD_FIELDS(value_seg,
		(size_t,	offset),/**< byte offset */
		(prop_type,	type),	/**< primitive type */
		(size_t,	count),	/**< number of contigious elements */
		(uint32_t,	mask),	/**< mask to be applied to the value */
		(ssize_t,	shift)	/**< shift to be applied to the value on extraction. if negative, left shift. if positive, right shift. */
	);

public:
	bool has_default_mask () const {
		switch (type()) {
			case BHND_T_UINT8:
			case BHND_T_INT8:
			case BHND_T_CHAR:
				return (mask() == 0xFF);
			case BHND_T_UINT16:
			case BHND_T_INT16:
				return (mask() == 0xFFFF);
			case BHND_T_UINT32:
			case BHND_T_INT32:
				return (mask() == 0xFFFFFFFF);
		}
	}
	
	bool has_default_shift () const {
		return (shift() == 0);
	}
	
	bool has_defaults () const {
		return (has_default_mask() && has_default_shift());
	}
	
	string description () const {
		NSMutableString *ret = [NSMutableString stringWithFormat: @"0x%zx", offset()];
		if (!has_defaults()) {
			[ret appendString: @" ("];
			if (!has_default_mask()) {
				[ret appendFormat: @"&0x%X", mask()];
				if (!has_default_shift())
					[ret appendString: @", "];
			}
			
			if (!has_default_shift()) {
				if (shift() < 0) {
					[ret appendFormat: @"<<%zd", shift()];
				} else {
					[ret appendFormat: @">>%zd", shift()];
				}
			}
			
			[ret appendString: @")"];
		}
		
		return (ret.UTF8String);
	}
};

/** SPROM value descriptor */
class value {
PL_RECORD_FIELDS(value,
	(shared_ptr<vector<value_seg>>, segments)	/**< segment(s) containing this value */
);

public:
	
	size_t total_width () const {
		uint32_t mask = 0;
		for (const auto &seg : *_segments) {
			
			if (seg.shift() < 0)
				mask |= (seg.mask() << (-seg.shift()));
			else
				mask |= (seg.mask() >> seg.shift());
		}
		
		if (mask & 0xFFFF0000)
			return 4;
		else if ((mask & 0x0000FF00) && (mask & 0xFF))
			return 2;
		else
			return 1;
	}
};

/** SPROM variable offset */
class sprom_offset {
	PL_RECORD_FIELDS(sprom_offset,
		(compat_range,			compat),/**< sprom compatibility declaration */
		(shared_ptr<vector<value>>,	values)	/**< value descriptor(s) */
	);


#if 0
	size_t elem_width () const {
		size_t max_width = 0;
		for (const auto &v : values)
			max_width = max(max_width, v.total_width());
		return max_width;
	}
#endif
};

PL_RECORD_STRUCT(sprom_struct,
	(compat_range,			compat),
	(shared_ptr<vector<uint16_t>>,	offsets)
);

/** NVRAM variable */
class var {
	PL_RECORD_FIELDS(var,
		(string,				name),
		(prop_type,				type),
		(str_fmt,				sfmt),
		(size_t,				count),
		(uint32_t,				flags),
		(shared_ptr<vector<sprom_offset>>,	sprom_offsets)
	);
public:
	bool operator < (const var &other) const {
		return ([@(name().c_str()) compare:@(other.name().c_str()) options:NSNumericSearch] == NSOrderedAscending);
	}
};
	

class phy {
public:
	PL_RECORD_FIELDS(phy, (int, ptype));
public:
    string name () const {
        switch (_ptype) {
            case PHY_TYPE_HT: return "HT";
            case PHY_TYPE_N: return "N";
            case PHY_TYPE_LP: return "LP";
            case PHY_TYPE_AC: return "AC";
            case PHY_TYPE_NULL: return "NULL";
            default:
                errx(EX_DATAERR, "unknown PHY type %d", _ptype);
        }
    };
};

class band {
	PL_RECORD_FIELDS(band, (int, btype));
public:
    string band_name () {
        switch (_btype) {
            case WL_CHAN_FREQ_RANGE_2G:         return "2G";
            case WL_CHAN_FREQ_RANGE_5G_BAND0:   return "5G U-NII-1 Low";
            case WL_CHAN_FREQ_RANGE_5G_BAND1:   return "5G U-NII-2 Mid";
            case WL_CHAN_FREQ_RANGE_5G_BAND2:   return "5G U-NII-3 High";
            case WL_CHAN_FREQ_RANGE_5G_BAND3:   return "5G U-NII-2e Worldwide"; // XXX ??? is this right
            case WL_CHAN_FREQ_RANGE_5G_4BAND:   return "5G (all bands)";
            default:                            errx(EX_DATAERR, "unknown band range %d", _btype);
        }
    }
};

class phy_band {
	PL_RECORD_FIELDS(phy_band,
		(class phy,	phy),
		(class band,	band)
	);
public:
    string description () {
        return (_phy.name() + " " + _band.band_name());
    }
};

class phy_chain {
	PL_RECORD_FIELDS(phy_chain,
		(phy_band,	pb),
		(uint32_t,	chain_num)
	);
public:
	string description () {
		return (pb().description() + " chain (" + to_string(chain_num()) + ")");
	}
};

class nvram_map {
private:
	unordered_map<string, shared_ptr<var>> _srom_tbl;
	unordered_multimap<string, phy_chain> _pavars;
	unordered_multimap<string, phy_band> _povars;

	void populate_pavars (const pavars_t *pas) {
		for (const pavars_t *pa = pas; pa->phy_type != PHY_TYPE_NULL; pa++) {
			auto pc = phy_chain(phy_band(phy(pa->phy_type), band(pa->bandrange)), pa->chain);
			auto *varstr = [@(pa->vars) componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
			for (NSString *str in varstr) {
				_pavars.insert({str.UTF8String, pc});
			}
		}
	}
	
public:
	nvram_map (const vector<shared_ptr<var>> &srom_vars) {
		for (const auto &v : srom_vars)
			_srom_tbl.insert({v->name(), v});
		
		populate_pavars(pavars);
		populate_pavars(pavars_bwver_1);
		populate_pavars(pavars_bwver_2);
		
		for (const povars_t *po = povars; po->phy_type != PHY_TYPE_NULL; po++) {
			auto pb = phy_band(phy(po->phy_type), band(po->bandrange));
			auto *varstr = [@(po->vars) componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
			for (NSString *str in varstr) {
				_povars.insert({str.UTF8String, pb});
			}
		}
	}
	
	void emit_diagnostics () {
		
	}
};


} /* namespace nvram */

namespace std {
	string to_string(nvram::prop_type t);
}