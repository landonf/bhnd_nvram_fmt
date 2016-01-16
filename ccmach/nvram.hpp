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

	bool builtin () { return (cis_tag != 0xFF); }
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
public:
	vector<var_set> var_sets () {
		unordered_map<string, var_set> sets;
		
		for (const auto &ct : _cis_consts) {
			symbolic_constant tag = ct.constant();
			ftl::maybe<symbolic_constant> hnbu_tag = ftl::nothing<symbolic_constant>();
			string name = ct.constant().name();

			if (strncmp(ct.constant().name().c_str(), "CISTPL_", strlen("CISTPL_")) == 0) {
				tag = ct.constant();
			} else {
				tag = symbolic_constant("CISTPL_BRCM_HNBU", CISTPL_BRCM_HNBU);
				hnbu_tag = ftl::just(ct.constant());
			}
			auto layout = get_layout(tag, hnbu_tag);
			
			NSString *comment = ct.comment();
			if (comment == nil)
				comment = @"";
			
			var_set vs(
				name,
				var_set_cis(tag, hnbu_tag, layout.compat()),
				comment.UTF8String,
				make_shared<vector<var>>()
			);
			sets.insert({ct.constant().name(), vs});
			printf("added %s->\n", ct.constant().name().c_str());
		}
		
		vector<var_set> result;
		for (const auto &kv : sets)
			result.push_back(kv.second);
		return result;
	}
	
	
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
	
	void emit_diagnostics () {
		vector<string> srom_undef;
		vector<string> cis_undef;
		vector<string> cis_layout_undef;

		fprintf(stderr, "# CIS vars missing revision ranges:\n");
		for (auto &vs : _cis_vstrs) {
			/* boardtype is aliased across HNBU_CHIPID and HNBU_BOARDTYPE; in HNBU_CHIPID, it's written
			 * as the subdevid */
			if (vs->cis_tag().name() == "HNBU_CHIPID" && vs->name() == "boardtype")
				continue;
			
			fprintf(stderr, "\t%s", vs->name().c_str());
			
			vector<nvram::compat_range> srom_compats;
			if (_srom_tbl.count(vs->name()) > 0) {
				const auto &svr = _srom_tbl.at(vs->name());
				
				for (const auto &sp : *svr->sprom_offsets())
					srom_compats.push_back(sp.compat());
			}
			
			if (!vs->has_hnbu_entry() && !vs->asserted_revmask() && srom_compats.size() == 0) {
				fprintf(stderr, "(no range found; assuming >= 0)");
			} else {
				NSMutableArray *elems = [NSMutableArray array];
				if (vs->has_hnbu_entry()) {
					[elems addObject: [NSString stringWithFormat: @"hnbu %s", nvram::compat_range::from_revmask(vs->hnbu_entry()->revmask).description().c_str()]];
				}
				
				if (srom_compats.size() != 0) {
					for (const auto &c : srom_compats)
						[elems addObject: [NSString stringWithFormat: @"srom %s", c.description().c_str()]];
				}
				
				if (vs->asserted_revmask()) {
					[elems addObject: [NSString stringWithFormat: @"asrt %s", nvram::compat_range::from_revmask(vs->asserted_revmask()).description().c_str()]];
				}
				
				fprintf(stderr, "(%s)", [elems componentsJoinedByString: @", "].UTF8String);
			}
			
			fprintf(stderr, "\n");
		}
		
		/* Find undefs */
		for (const auto &v : _cis_vstr_tbl)
			if (_srom_tbl.count(v.first) == 0)
				srom_undef.push_back(v.first);
		
		for (const auto &v : _cis_vstr_tbl)
			if (_cis_layout_tbl.count(v.first) == 0)
				cis_layout_undef.push_back(v.first);
		
		for (const auto &v : _srom_tbl)
			if (_cis_vstr_tbl.count(v.first) == 0 && _cis_layout_tbl.count(v.first) == 0)
				cis_undef.push_back(v.first);
		
		alpha_sort(srom_undef);
		alpha_sort(cis_undef);
		alpha_sort(cis_layout_undef);

		fprintf(stderr, "# SROM vars not defined in CIS (no substitute groupings defined):\n");
		auto varb_regex = [NSRegularExpression regularExpressionWithPattern: @"[0-9]([a-z][0-9])?$" options: 0 error: nil];
		for (const auto &v : cis_undef) {
			auto base = v;
			string match;
			bool found_match = false;

			base.pop_back();
			while (base.size() >= 3 && !found_match) {
				for (const auto &vstr : _cis_vstr_tbl) {
					if ([@(vstr.first.c_str()) hasPrefix: @(base.c_str())]) {
						match = vstr.first;
						found_match = true;
						break;
					}
				}
				base.pop_back();
				if (![varb_regex matchesInString: @(base.c_str()) options: 0 range: NSMakeRange(0, base.size())])
					break;
			}
			
			if (srom_subst_groupings.count(v) != 1) {
				if (!found_match) {
					fprintf(stderr, "\t%s\n", v.c_str());
				} else {
					const auto &entry = _cis_vstr_tbl.at(match);
					fprintf(stderr, "\t%s (found base %s family %s)\n", v.c_str(), match.c_str(), entry->cis_tag().name().c_str());
				}
				
				errx(EXIT_FAILURE, "no substitute grouping defined for %s", v.c_str());
			}
		}

		


		fprintf(stderr, "# CIS vars not defined in SPROM:\n");
		for (const auto &v : srom_undef)
			fprintf(stderr, "\t%s\n", v.c_str());


		fprintf(stderr, "# CIS vars requiring special case decoding:\n");
		for (const auto &l : _cis_layouts) {
			for (const auto &v : l.vars()) {
				if (v.special_case() && cis_subst_layout.count(v.name()) == 0 && cis_known_special_cases.count(v.name()) == 0) {
					fprintf(stderr, "\t%s", v.name().c_str());
					if (_srom_tbl.count(v.name()) > 0) {
						auto srom_offset = _srom_tbl.at(v.name())->sprom_offsets()->at(0);
						if (srom_offset.values()->size() == 1 && srom_offset.values()->at(0).segments()->size() == 1) {
							auto srom_seg = srom_offset.values()->at(0).segments()->at(0);
							fprintf(stderr, " : { \"%s\", { <OFFSET>, %s, %zu, 0x%X, %zd }},\n",
								v.name().c_str(),
								prop_type_str(srom_seg.type()).c_str(),
								srom_seg.count(),
								srom_seg.mask(),
								srom_seg.shift());

						} else {
							fprintf(stderr, " (found complex srom var layout)\n");
						}
					} else {
						fprintf(stderr, "\n");
					}
					errx(EXIT_FAILURE, "explicit layout definition required for %s", v.name().c_str());
				}
			}
		}
		
		fprintf(stderr, "# CIS vars missing layout records:\n");
		for (const auto &v : cis_layout_undef) {
			if (cis_subst_layout.count(v) > 0 || cis_known_special_cases.count(v) > 0)
				continue;
			
			fprintf(stderr, "\t%s", v.c_str());
			if (_srom_tbl.count(v) > 0) {
				auto srom_offset = _srom_tbl.at(v)->sprom_offsets()->at(0);
				if (srom_offset.values()->size() == 1 && srom_offset.values()->at(0).segments()->size() == 1) {
					auto srom_seg = srom_offset.values()->at(0).segments()->at(0);
					fprintf(stderr, " : { \"%s\", { <OFFSET>, %s, %zu, 0x%X, %zd }},\n",
						v.c_str(),
						prop_type_str(srom_seg.type()).c_str(),
						srom_seg.count(),
						srom_seg.mask(),
						srom_seg.shift());
					
				} else {
					fprintf(stderr, " (found complex srom var layout)\n");
				}
			} else {
				fprintf(stderr, "\n");
			}
			errx(EXIT_FAILURE, "explicit layout definition required for %s", v.c_str());
		}

	}
};


} /* namespace nvram */

namespace std {
	string to_string(nvram::prop_type t);
}

#include "cis_layout_desc.hpp"
