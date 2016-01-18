//
//  nvram_map.h
//  ccmach
//
//  Created by Landon Fuller on 1/1/16.
//  Copyright (c) 2016 Landon Fuller. All rights reserved.
//

#pragma once

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

#include "nvtypes.h"
#include "cis_layout_desc.hpp"

using namespace std;
using namespace pl;

namespace nvram {

struct grouping {
	const char	*name;
	const char	*desc;
	uint8_t		 cis_tag; // if any, or 0xFF.

	bool builtin () const { return (cis_tag != 0xFF); }
};

extern unordered_map<string, grouping&> srom_subst_groupings;
extern unordered_map<string, nvram::value_seg> cis_subst_layout;
extern unordered_set<string> cis_known_special_cases;
	
class genmap;

class nvram_map {
	friend class genmap;
private:
	vector<shared_ptr<var>> _srom_vars;
	vector<shared_ptr<cis_vstr>> _cis_vstrs;
	vector<nvram::cis_tag> _cis_consts;
	vector<cis_layout> _cis_layouts;

	unordered_map<string, shared_ptr<var>> _srom_tbl;
	unordered_map<string, shared_ptr<cis_vstr>> _cis_vstr_tbl;
	unordered_multimap<string, cis_layout> _cis_layout_tbl;
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
	
	void alpha_sort (std::vector<string> &v) {
		sort(v.begin(), v.end(), [](const string &lhs, string &rhs) {
			return ([@(lhs.c_str()) compare: @(rhs.c_str()) options: NSCaseInsensitiveSearch|NSNumericSearch] == NSOrderedAscending);
		});
	}
	
	const cis_layout &get_layout (const symbolic_constant &tag, ftl::maybe<symbolic_constant> &hnbu_tag) {
		for (const auto &l : _cis_layouts) {
			if (l.code() == tag && l.hnbu_tag() == hnbu_tag)
				return l;
		}
		
		errx(EXIT_FAILURE, "layout for %s:%s not found", tag.name().c_str(), hnbu_tag.is<symbolic_constant>() ? ftl::get<symbolic_constant>(hnbu_tag).name().c_str() : "<none>");
	}
	
	bool has_vstr (const string &vname) {
		auto vn = vname;
		
		if (_cis_vstr_tbl.count(vname) == 0) {
			char last = vn[vn.size() - 1];
			if (isdigit(last) && last != '0')
				vn[vn.size() - 1] = '0';
		}
		
		return (_cis_vstr_tbl.count(vname) > 0);
	}
	
	shared_ptr<cis_vstr> get_vstr (const string &vname) {
		auto vn = vname;

		if (_cis_vstr_tbl.count(vname) == 0) {
			char last = vn[vn.size() - 1];
			if (isdigit(last) && last != '0')
				vn[vn.size() - 1] = '0';
		}
		
		if (_cis_vstr_tbl.count(vn) == 0)
			errx(EXIT_FAILURE, "missing vstr for %s", vname.c_str());

		return _cis_vstr_tbl.at(vn);
	}
public:
	vector<shared_ptr<var_set>> var_sets ();
	
	nvram_map (const vector<shared_ptr<var>> &srom_vars,
		   const vector<shared_ptr<cis_vstr>> &cis_vstrs,
		   const vector<nvram::cis_tag> &cis_consts,
		   const vector<cis_layout> &cis_layouts) : _srom_vars(srom_vars), _cis_vstrs(cis_vstrs), _cis_consts(cis_consts), _cis_layouts(cis_layouts)
	{
		for (const auto &v : srom_vars)
			_srom_tbl.insert({v->name(), v});
		
		for (const auto &v : cis_vstrs)
			_cis_vstr_tbl.insert({v->name(), v});
		
		for (const auto &l : cis_layouts) {
			for (const auto &v : l.var_names())
				_cis_layout_tbl.insert({v, l});
		}

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
	
	unordered_set<string> vars () {
		unordered_set<string> vset;
		for (const auto &v : _srom_vars)
			vset.insert(v->name());
		for (const auto &v : _cis_vstrs)
			vset.insert(v->name());
		for (const auto &l : _cis_layouts)
			for (const auto &v : l.vars())
				vset.insert(v.name());
		
		return vset;
	}
	
	void emit_diagnostics ();
};


} /* namespace nvram */

namespace std {
	string to_string(nvram::prop_type t);
	string to_string(nvram::str_fmt t);
}

#include "cis_layout_desc.hpp"
