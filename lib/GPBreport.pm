#!/usr/bin/perl

package GPBreport;

use strict;
use warnings;
use JSON;
use MIME::Base64 qw(encode_base64);


my %dna_to_bin = (
    'A' => '000',
    'T' => '001',
    'C' => '010',
    'G' => '011',
    'N' => '100'
);


sub compress_dna {
    my ($dna_seq) = @_;
    $dna_seq = uc($dna_seq);

    $dna_seq =~ s/[^ATCGN]/N/g;
    
    if (length($dna_seq) <= 4) {
        return encode_base64(pack('C', 0) . $dna_seq, '');
    }
    
    my $binary_str = '';
    foreach my $base (split //, $dna_seq) {
        $binary_str .= $dna_to_bin{$base};
    }
    my $padding = (8 - (length($binary_str) % 8)) % 8;
    $binary_str .= '0' x $padding;
    my $bytes = '';
    while (length($binary_str) >= 8) {
        my $byte_bin = substr($binary_str, 0, 8, '');
        $bytes .= pack('C', oct("0b$byte_bin"));
    }
    my $compressed = pack('C', 1) . pack('C', $padding) . $bytes;
    return encode_base64($compressed, '');
}


sub export_figure {
	my ($dir, $pfx, $final_nodes, $edge_out, $ref_info, $all_gene_pos, $bed_data, $pheno_meta) = @_;

	my %all_sample;
	$all_sample{$_} = 1 for map { split /,/, $_->[2] } @$final_nodes;
	my @sample_list = sort keys %all_sample;
	my %sample_cnt;

	for my $node (@$final_nodes) {
		%sample_cnt = (); 
		$sample_cnt{$_}++ for split /,/, $node->[2];

		my @freq = map { $sample_cnt{$_} || 0 } @sample_list;
		pop @freq while @freq && $freq[-1] == 0;

		if (@freq == @sample_list && !grep { $_ != 1 } @freq) {
			$node->[2] = 'ALL';
		}else{
			$node->[2] = join ',', map { $_ || '' } @freq;
		}

		if($node->[1] ne ''){
			$node->[1] = compress_dna($node->[1]);
		}
	}
	
	my %out = (
                graphData => {
                        node => $final_nodes,
                        edge => $edge_out,
                        ref => $ref_info
                },
		sampleList => join(',', @sample_list),
                geneAnnoData => $all_gene_pos,
                bedAnnoData => $bed_data,
                phenoMeta => $pheno_meta
        );
	my $out_json = encode_json(\%out);

	open my $fh_fig, '>', "$dir/$pfx.html" or die "Error: Can't write file '$dir/$pfx.html': $!\n";

	my $html = '<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>GPB report</title>
<link rel="stylesheet" type="text/css" href="./css/bootstrap_5.1.1_css_bootstrap.min.css">
<script type="text/javascript" charset="utf8" src="./js/jquery-3.5.1.js"></script> 
<script type="text/javascript" charset="utf8" src="./js/echarts.js"></script> 
<script type="text/javascript" charset="utf8" src="./js/bootstrap_5.1.1_js_bootstrap.bundle.min.js"></script> 
<script type="text/javascript" charset="utf8" src="./js/splitedData.js"></script> 
<script type="text/javascript" charset="utf8" src="./js/nodesLayout.js"></script> 
<script type="text/javascript" charset="utf8" src="./js/plottingSets.js"></script>
<script type="text/javascript" charset="utf8" src="./js/nodesInfo.js"></script>
</head>

<body>
<div class="container" style="margin-top:20px;width:90%">
  <div class="row">
    <table width="350px">
      <tr>
        <td><b>Chromosome:</b></td>
        <td id = "region_chr"></td>
      </tr>
      <tr>
        <td><b>Start:</b></td>
        <td id = "region_start"></td>
      </tr>
      <tr>
        <td><b>End:</b></td>
        <td id = "region_end"></td>
      </tr>
    </table>
  </div>
  <br>
  <hr>
  <br>
  <div id="phenoPanel" class="container mt-4">
    <div class="d-flex gap-2">
      <select id="phenSelected" class="form-select form-select-sm w-auto">
      </select>
      <button id="refreshBtn" class="btn btn-primary btn-sm"> <i class="bi bi-arrow-clockwise" id="refreshIcon"></i> Refresh </button>
    </div>
  </div>
  <br>
  <div class="row">
    <div id="main" style="width:100%;height:800px"></div>
  </div>
  <p id="nodePanelText"> <small style="color: gray">Please click on the sequence blocks in the figure to view the corresponding sequence, genome list.</small> </p>
  <div class="row" id="nodePanel" style="width:90%; margin:0 auto;">
    <div id="nodePanelSeq"></div>
    <div class="col-12 mb-3"></div>
    <div id="nodePanelSample"></div>
  </div>
  <br>
</div>
<script>
	
$(document).ready(function () {
  const chart = echarts.init(document.getElementById("main"));
    const jsonText = `'.$out_json.'`;
    const data = JSON.parse(jsonText);
    const graphData = data.graphData;
    const geneData = data.geneAnnoData;
    const bedData = data.bedAnnoData;
    const phenoMetaData = data.phenoMeta;
    const nodeData = getNodeData(graphData.node, data.sampleList);

    var strucColors = {
      "gene": "#36648B",
      "transcript": "#A1A1A1",
      "exon": "#A1A1A1",
      "CDS": "#1368BD",
      "UTR3": "#68A3DE",
      "UTR5": "#68A3DE"
    };

    const refNodeColors = ["#424242", "#757575"];
    const altNodePalette = ["#3BA272", "#FAC858", "#73C0DE", "#EE6666", "#91CC75", "#5470C6", "#EA7CCC", "#FC8452"];
    const refAreaColor = "#ebf0e4";
    const arrowColor = "#bababa";
    const axisPointerColor = "#e38e28";
    const bedColor = "gray";

    const arrorWidth = 0.5;
    const yMax = graphData.edge.filter(r=>r[0]==="0+").reduce((s,r)=>s+r[2],0);

    document.getElementById("region_chr").innerHTML = graphData.ref.chr
    document.getElementById("region_start").innerHTML = graphData.ref.start
    document.getElementById("region_end").innerHTML = graphData.ref.end

    let phenoNameList = [];
    if (phenoMetaData !== "") {
      phenoNameList = phenoMetaData.map(item => item[0]);
      const sel = document.getElementById("phenSelected");
      sel.innerHTML = "";
      phenoNameList.forEach(v => {
        sel.add(new Option(v, v));
      });
    } else {
      document.getElementById("phenoPanel").style.display = "none";
    }

    const graphStart = Number(graphData.ref.start) + 1;
    const nodeSeq = getNodeSeq(nodeData);
    const nodeSample = new Map(nodeData.map(row => [row[0], row[2]]));
    const nodeSampleN = statNodeSampleN(graphData.edge);

    const refNodes = graphData.ref.nodes.split(",");
    const allEdges = graphData.edge;
    const allNodes = new Set(allEdges.flatMap(edge => [edge[0], edge[1]]));
    const sortedNodes = sortNodes(allNodes, allEdges, refNodes);
    const groupedEdge = getGroupedEdge(graphData, sortedNodes);
    mergeReverse(sortedNodes, groupedEdge, nodeSeq, nodeSample, nodeData);

    const nodeXPos = getNodeXPos(nodeSeq, sortedNodes);
    const xMin = 0.5;
    const xMax = nodeXPos[sortedNodes[sortedNodes.length - 1]].xend;
    const refMergedRange = getRefRange(nodeXPos, refNodes);
    const refMarkedArea = convertRangesToMarkedAreas(refMergedRange);

    const {
      nodeYRange,
      blockArror,
      lineData
    } = layoutAll(sortedNodes, groupedEdge, nodeXPos, yMax);
    const {
      seriesBlockList,
      blockNode,
      blockColors
    } = getBlockSeries(nodeXPos, nodeYRange, blockArror, sortedNodes, nodeSampleN, arrorWidth, refNodes, refNodeColors, altNodePalette);
    const seriesLineList = getLineSeries(lineData, arrorWidth, arrowColor);

    const {
      graphNodePos,
      seriesGraphNodeList
    } = getGraphNodeSeries(nodeXPos, blockNode, blockColors, 0.9);
    const seriesGraphEdgeList = getGraphEdgeSeries(graphNodePos, groupedEdge);

    const newXLabel = splitXAxis(refMergedRange, graphStart);

    const {
      strucData,
      strucYtext
    } = getStrucData(geneData, strucColors);
    const strucSplitedData = splitStruc(strucData, refMergedRange, graphStart);
    const seriesGeneStruc = getStrucSeries(strucSplitedData, refAreaColor, refMarkedArea);
    const seriesGeneStrand = getStrandSeries(strucSplitedData);

    const {
      bedSplitedData,
      bedYtext
    } = splitBed(bedData, graphStart, refMergedRange, bedColor);
    const seriesBed = getBedSeries(bedSplitedData, refAreaColor, refMarkedArea);


    let phenGroupName = "";
    let seriesPhenTrackList = [];
    let phenoYmax = yMax;
    let phenTrackMaxN = 0;

    function refreshChart() {
      if (phenoMetaData !== "") {
        const curPhen = document.getElementById("phenSelected").value;
        const curPhenIdx = phenoNameList.indexOf(curPhen);
        const curPhenInfo = phenoMetaData.find(item => item[0] === curPhen);
        const phenData = Object.fromEntries(
          nodeData.map(a => {
            const arr = a[3][curPhenIdx];
            return [a[0], arr.slice(1).concat(arr[0])];
          })
        );
        if (curPhenInfo[1]) {
          phenGroupName = [phenoMetaData[curPhenIdx][0]];
          phenoYmax = Math.max(...Object.values(phenData).flatMap(a => a.slice(2, 5)));
          seriesPhenTrackList = getConPhenTrackSeries(phenData, phenGroupName, nodeXPos, 4, blockColors, refAreaColor, refMarkedArea);
        } else {
          phenGroupName = [...phenoMetaData[curPhenIdx][2]];
          const hasLastGt0 = Object.values(phenData)
            .some(arr => Array.isArray(arr) && arr.length > 0 && arr.at(-1) > 0);
          if (hasLastGt0) {
            phenGroupName.push("MISSING");
          }
          phenoYmax = Math.max(...Object.values(phenData).flat());
          seriesPhenTrackList = getDisPhenTrackSeries(phenData, phenGroupName, nodeXPos, 4, blockNode, blockColors, refAreaColor, refMarkedArea);
        }
        phenTrackMaxN = phenGroupName.length;

      }
      const {
        option,
        totalHeight
      } = getChartOption(axisPointerColor, xMin, xMax, newXLabel, yMax, strucYtext, bedYtext, phenTrackMaxN, phenGroupName, phenoYmax, seriesBlockList, seriesGraphNodeList, seriesGraphEdgeList, seriesLineList, seriesGeneStruc, seriesGeneStrand, seriesBed, seriesPhenTrackList);

      const dom = document.getElementById("main");
      dom.style.height = totalHeight + "px";

      chart.resize();
      chart.clear();
      chart.setOption(option);
    }

    refreshChart();
    document.getElementById("refreshBtn").addEventListener("click", refreshChart);

    chart.off("click").on("click", function (params) {
      if (params.componentSubType == "custom" && params.value.length == 2) {
        const curNode = blockNode[params.seriesIndex];
        if (curNode) {
          document.getElementById("nodePanelText").hidden = true;
          document.getElementById("nodePanel").hidden = false;
          fillNodePanel(curNode, nodeSeq, nodeSample);
        }
      }
    });
})

	
</script>
</body>
</html>';

	print $fh_fig $html;
	close $fh_fig;

}


sub export_report {
        my ($json_file) = @_;
	my $report = '<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>GPB report</title>
<link rel="stylesheet" type="text/css" href="./css/bootstrap_5.1.1_css_bootstrap.min.css">
<script type="text/javascript" charset="utf8" src="./js/jquery-3.5.1.js"></script> 
<script type="text/javascript" charset="utf8" src="./js/echarts.js"></script> 
<script type="text/javascript" charset="utf8" src="./js/bootstrap_5.1.1_js_bootstrap.bundle.min.js"></script> 
<script type="text/javascript" charset="utf8" src="./js/splitedData.js"></script> 
<script type="text/javascript" charset="utf8" src="./js/nodesLayout.js"></script> 
<script type="text/javascript" charset="utf8" src="./js/plottingSets.js"></script>
</head>

<body>
<div class="container" style="margin-top:20px;width:90%">
  <div class="row">
    <table width="350px">
      <tr>
        <td><b>Gene ID:</b></td>
        <td id = "gene_id"></td>
      </tr>
      <tr>
        <td><b>Chromosome:</b></td>
        <td id = "gene_chr"></td>
      </tr>
      <tr>
        <td><b>Start:</b></td>
        <td id = "gene_start"></td>
      </tr>
      <tr>
        <td><b>End:</b></td>
        <td id = "gene_end"></td>
      </tr>
      <tr>
        <td><b>Strand:</b></td>
        <td id = "gene_strand"></td>
      </tr>
    </table>
  </div>
  <br>
  <hr>
  <br>
  <div class="row">
    <div id="main" style="width:100%;height:800px"></div>
  </div>
	<p id="nodePanelText"> <small style="color: gray">Please click on the sequence blocks in the figure to view the corresponding sequence, genome list.</small> </p>
  
  <div class="row" id="nodePanel" style="width:90%; margin:0 auto;">
    <div id="nodePanelSeq"></div>  
	<div class="col-12 mb-3"></div>
    <div id="nodePanelSample"></div>
  </div>
</div>
<script>
	
$(document).ready(function() {
	const chart = echarts.init(document.getElementById("main"));	  
	$.getJSON("'.$json_file.'").done(function(data){
		console.dir(data);
		const graphData = data.graphData;
		const geneData = data.geneData;
		const transData = data.transData;
		const elementData = data.elementData;

		elementData.sort((a, b) => {
		if (a[3] === "exon" && b[3] !== "exon") return -1;
		if (a[3] !== "exon" && b[3] === "exon") return 1;
		return 0;
		});

		var strucColors = {
		"gene": "#36648B", 
		"transcript": "#A1A1A1",
		"exon": "#A1A1A1", 
		"CDS": "#1368BD",
		"UTR3": "#68A3DE",
		"UTR5": "#68A3DE"
		};

		const refNodeColors = ["#424242", "#757575"];
		const altNodePalette = ["#3BA272", "#FAC858", "#73C0DE", "#EE6666", "#91CC75", "#5470C6", "#EA7CCC", "#FC8452"];
		const refAreaColor = "#ebf0e4";
		const arrorColor = "#E8E8E8";
		const axisPointerColor = "#e38e28";

		const arrorWidth = 0.5;
		const sample_list = graphData.edge.map(subArr => subArr[2]);
		const sample_n = Math.max(...sample_list);

		document.getElementById("gene_id").innerHTML = geneData.gene_id
		document.getElementById("gene_chr").innerHTML = geneData.chr
		document.getElementById("gene_start").innerHTML = geneData.start
		document.getElementById("gene_end").innerHTML = geneData.end
		document.getElementById("gene_strand").innerHTML = geneData.strand

		const graphStart = Number(graphData.ref.start) + 1;
		const nodeSeq = new Map(graphData.node);
		const nodeSample = new Map(graphData.node.map(row => [row[0], row[2]]));
		const nodeSampleN = statNodeSampleN(graphData.edge);
		
		const refNodes = graphData.ref.nodes.split(",");
		const allEdges = graphData.edge;
		const allNodes = new Set(allEdges.flatMap(edge => [edge[0], edge[1]]));
		const sortedNodes = sortNodes(allNodes, allEdges, refNodes);

		const nodeXPos = getNodeXPos(graphData, sortedNodes);
		const xMin = 0.5;
		const xMax = nodeXPos[sortedNodes[sortedNodes.length - 1]].xend;
		const refMergedRange = getRefRange(nodeXPos, refNodes);
		const refMarkedArea = convertRangesToMarkedAreas(refMergedRange);		
		const groupedEdge = getGroupedEdge(graphData, sortedNodes);

		const {
		nodeYRange,
		blockArror,
		lineData
		} = layoutAll(sortedNodes, groupedEdge, nodeXPos, sample_n);

		const {
		seriesBlockList,
		blockNode,
		blockColors
		} = getBlockSeries(nodeXPos, nodeYRange, blockArror, sortedNodes, nodeSampleN, arrorWidth, refNodes, refNodeColors, altNodePalette);

		const seriesLineList = getLineSeries(lineData, arrorWidth, arrorColor);

		const {
		graphNodePos,
		seriesGraphNodeList
		} = getGraphNodeSeries(nodeXPos, blockNode, blockColors, 0.9);

		const seriesGraphEdgeList = getGraphEdgeSeries(graphNodePos, groupedEdge);

		const seriesGraphList = getGraphSeries(nodeXPos, groupedEdge, blockNode, blockColors);

		newXLabel = splitXAixs(refMergedRange, graphStart);

		const {
		strucData,
		strucYtext
		} = getStrucData(geneData, transData, elementData, strucColors);
		strucSplitedData = splitStuc(strucData, refMergedRange, graphStart);

		const seriesGeneStruc = getStrucSeries(strucSplitedData, refAreaColor, refMarkedArea);
		const panelStrucN = strucYtext.length >= 1 ? strucYtext.length : 1;

		const option = getChartOption(axisPointerColor, xMin, xMax, newXLabel, sample_n, strucYtext, seriesBlockList, seriesGraphNodeList, seriesGraphEdgeList, seriesLineList, seriesGeneStruc);
		
		chart.setOption(option);
		
		chart.off("click").on("click", function (params) {
			if (params.componentSubType == "custom" && params.value.length == 2) {				
				const curNode = blockNode[params.seriesIndex];
				if (curNode) {
					document.getElementById("nodePanelText").hidden = true;
					document.getElementById("nodePanel").hidden = false;
					document.getElementById("nodePanelSeq").innerHTML = "<b>Sequence of node " + curNode + \':</b><textarea class="form-control" readonly  style="width:100%;font-family:Courier New,monospace;font-size:13px;resize:none;margin-left:0%" rows="5" >\' + nodeSeq.get(curNode) + "</textarea>";
					const curSampleAll = nodeSample.get(curNode).split(",");
					document.getElementById("nodePanelSample").innerHTML = "<b>Detected " + curSampleAll.length + " path(s) from " + [...new Set(curSampleAll)].length + \' genome(s) :</b><textarea class="form-control" readonly style="width:100%;font-family:Courier New,monospace;font-size:13px;resize:none;margin-left:0%;height:180px">\' + curSampleAll.join(", ") + "</textarea>";
				}			
			}
		});
		
	  });	
})
	
</script>
</body>
</html>
';
        return($report);
}



1;
