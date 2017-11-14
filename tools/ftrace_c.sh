#!/bin/bash


AWKPROG_P='
BEGIN {
	f = 0
	t_s = 0
	t_e = 0
	t_total = 0
	MATCH_S = "NULL"
	MATCH_E = "NULL"

	if(match(pair, "se")) {
		MATCH_S = "start"	
		MATCH_E = "end"
	} else if(match(pair, "fmwd")) {
		MATCH_S = "wait$"
		MATCH_E = "wait_done"
	} else if(match(pair, "fmrd")) {
		MATCH_S = "read$"
		MATCH_E = "read_done"
	} else if(match(pair, "swrd")) {
		MATCH_S = "rd$"
		MATCH_E = "rd_done"
	} else if(match(pair, "bg")) {
		MATCH_S = "begin"
		MATCH_E = "end"
	}
}
{
	if(match($5,MATCH_S)) { 
		f = 1
		t_s = $4
	} else if(match($5,MATCH_E)) {
		if(f == 1) {
			f = 0
			t_e = $4
			t_total += (t_e - t_s)
		}
	}
}
END {
		print item ": " t_total "s" 
}
'

grep "mm_shrink_slab_start\|mm_shrink_slab_end" $1 | awk -v item=mm_shrink_slab  -v pair=se "$AWKPROG_P"
grep "mm_fmflt_op_wait\|mm_fmflt_op_wait_done" $1 | awk -v item=mm_fmflt_op_wait  -v pair=fmwd "$AWKPROG_P"
grep "mm_fmflt_op_read\|mm_fmflt_op_read_done" $1 | awk -v item=mm_fmflt_op_read  -v pair=fmrd "$AWKPROG_P"
grep "mm_swap_op_rd\|mm_swap_op_rd_done" $1 | awk -v item=mm_swap_op_rd  -v pair=swrd "$AWKPROG_P"
grep "mm_vmscan_memcg_softlimit_reclaim_begin\|mm_vmscan_memcg_softlimit_reclaim_end" $1 | awk -v item=mm_vmscan_memcg_softlimit_reclaim  -v pair=be "$AWKPROG_P"
grep "mm_vmscan_memcg_reclaim_begin\|mm_vmscan_memcg_reclaim_end" $1 | awk -v item=mm_vmscan_memcg_reclaim  -v pair=be "$AWKPROG_P"
grep "mm_vmscan_direct_reclaim_begin\|mm_vmscan_direct_reclaim_end" $1 | awk -v item=mm_vmscan_direct_reclaim  -v pair=be "$AWKPROG_P"


grep "mm_vmscan_kswapd_wake" $1 | wc -l  | awk '{print "mm_vmscan_kswapd_wake: " $1 " times"}'
grep "mm_vmscan_kswapd_sleep" $1 | wc -l | awk '{print "mm_vmscan_kswapd_sleep: " $1 " times"}'
grep "mm_filemap_add_to_page_cache" $1 | wc -l | awk '{print "mm_filemap_add_to_page_cache: " $1 " times" }'
grep "mm_filemap_delete_from_page_cache" $1 | wc -l | awk '{print "mm_filemap_delete_from_page_cache: " $1 " times"}'

