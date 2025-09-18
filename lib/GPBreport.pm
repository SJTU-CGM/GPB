#!/usr/bin/perl

package GPBreport;

use strict;
use warnings;

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
