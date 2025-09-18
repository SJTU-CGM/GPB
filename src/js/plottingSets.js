// JavaScript Document

function getGraphSeries(nodeXPos, groupedEdge, blockNode, blockColors) {

  const nodeHeight = 10;
  const nodeWidhtPer = 0.2;

  const nodeData = [];
  const linkData = [];

  Object.keys(nodeXPos).forEach(key => {
    const curNode = nodeXPos[key];
    const curWidth = curNode.xend - curNode.xstart;
    const curX = curNode.xstart + curWidth / 2;
    const curY = 0;

    nodeData.push({
      name: key,
      value: [curX, curY],
      symbolSize: [curWidth * nodeWidhtPer, nodeHeight],
      itemStyle: {
        color: blockColors[blockNode.indexOf(key)]
      }
    })

    if (groupedEdge[key]) {
      groupedEdge[key].forEach(item => {
        linkData.push({
          source: item[0],
          target: item[1],
          lineStyle: {
            width: 3,
            curveness: 0.1
          }
        })
      })
    }

  })

  return {
    type: 'graph',
    layout: 'none',
    coordinateSystem: 'cartesian2d',
    symbol: 'rect',
    draggable: true,
    symbolSize: 1,
    roam: true,
    label: {
      show: false
    },
    //edgeSymbol: ['circle', 'arrow'],
    edgeSymbolSize: [4, 10],
    data: nodeData,
    links: linkData,
    lineStyle: {
      opacity: 0.9,
      width: 1,
      curveness: 0
    },
    xAxisIndex: 0,
    yAxisIndex: 0,
    clip: true,
    large: true,
    emphasis: {
      disabled: true
    },
    tooltip: {
      show: false
    }

  }

}

function getGraphNodeSeries(nodeXPos, blockNode, blockColors, blockWidth) {

  const graphDataList = [];
  const graphNodePos = {};
  const blockHeight = 1;
  Object.keys(nodeXPos).forEach(key => {
    //const curWidth = (nodeXPos[key].xend - nodeXPos[key].xstart) * (1 - blockWidth);
    const curWidth = nodeXPos[key].xend - nodeXPos[key].xstart;
    const curP = 0.9 + 0.1 * (1 - 1 / (1 + Math.log2(curWidth + 1)));
    const curW = curWidth * (1 - curP)
    if (curWidth > 0) {
      graphDataList.push([
        [nodeXPos[key].xstart + curW / 2, 0 - blockHeight / 2],
        [nodeXPos[key].xstart + curW / 2, 0 + blockHeight / 2],
        [nodeXPos[key].xend - curW / 2, 0 + blockHeight / 2],
        [nodeXPos[key].xend - curW / 2, 0 - blockHeight / 2],
        blockColors[blockNode.indexOf(key)]
      ]);
      graphNodePos[key] = {
        xstart: nodeXPos[key].xstart + curW / 2,
        xend: nodeXPos[key].xend - curW / 2
      }
    }

  })

  const seriesGraphNodeList = graphDataList.map(data => {
    return {
      type: 'custom',
      renderItem: function (params, api) {
        if (params.context.rendered) {
          return;
        }
        params.context.rendered = true;
        let points = [];
        for (let i = 0; i < data.length; i++) {
          points.push(api.coord(data[i]));
        }
        return {
          type: 'polygon',
          transition: ['shape'],
          shape: {
            points: points
          },
          style: {
            fill: data[4] //"black"
          }
        };
      },
      xAxisIndex: 0,
      yAxisIndex: 0,
      encode: {
        x: 0,
        y: 0
      },
      clip: true,
      data: data[0, 1, 2, 3],
      large: true,
      emphasis: {
        disabled: true
      },
      tooltip: {
        show: false
      }

    }
  });

  return {
    graphNodePos,
    seriesGraphNodeList
  };

}

function getGraphEdgeSeries(graphNodePos, groupedEdge) {


  const seriesGraphEdgeList = Object.keys(groupedEdge).map(key => {

    const graphNodes = [];
    const graphLinks = [];

    if (graphNodePos[key]) {
      graphNodes.push({
        name: key,
        value: [graphNodePos[key].xend, 0.5]
      });
      groupedEdge[key].forEach(item => {
        if (item[1] != "Inf+") {
          graphNodes.push({
            name: item[1],
            value: [graphNodePos[item[1]].xstart, 0.5]
          })
          graphLinks.push({
            source: item[0],
            target: item[1],
            lineStyle: {
              width: 3,
              curveness: 0.4
            }
          })

        }

      })
    }


    return {
      type: 'graph',
      layout: 'none',
      coordinateSystem: 'cartesian2d',
      symbol: 'none',
      symbolSize: 1,
      roam: true,
      label: {
        show: false
      },
      //edgeSymbol: ['circle', 'arrow'],
      edgeSymbolSize: [4, 10],
      data: graphNodes,
      links: graphLinks,
      lineStyle: {
        opacity: 0.9,
        width: 1,
        curveness: 0
      },
      xAxisIndex: 0,
      yAxisIndex: 0,
      clip: true,
      large: true,
      emphasis: {
        disabled: true
      },
      tooltip: {
        show: false
      }

    }

  })


  return (seriesGraphEdgeList);
}

function getBlockSeries(nodeXPos, nodeYRange, blockArror, sortedNodes, nodeSampleN, arrorWidth, refNodes, refNodeColors, altNodePalette) {
  const blockDataList = [];
  const blockColors = [];
  const blockNode = [];
  let altNodeNum = 0;
  let refNodeNum = 0;

  const maxSampleN = Math.max(...Array.from(nodeSampleN.values()));

  sortedNodes.forEach((node, idx) => {
    //Object.keys(nodeYRange).forEach((node, idx) => {
    if (node != "0+" && node != "Inf+") {

      const cur_color = 255 - 60 - (nodeSampleN.get(node) / maxSampleN) * 100;

      if (blockArror[node]) {
        arrPos = blockArror[node];
        nodeYRange[node].forEach(block => {
          const points = [
            [nodeXPos[node].xstart, -block.ystart],
            [nodeXPos[node].xstart, -block.yend],
            [nodeXPos[node].xend, -block.yend]
          ];
          arrPos.forEach(item => {
            if (item[0] > block.ystart && item[1] < block.yend) {
              points.push([nodeXPos[node].xend, -item[0]]);
              //points.push([nodeXPos[node].xend + arrorWidth, -((item[0] + item[1])/2 + (item[0]-item[1])/3)]);
              points.push([nodeXPos[node].xend + arrorWidth, -(item[0] + item[1]) / 2]);
              //points.push([nodeXPos[node].xend + arrorWidth, -((item[0] + item[1])/2 -(item[0]-item[1])/3)]);
              points.push([nodeXPos[node].xend, -item[1]]);
            }
          });
          points.push([nodeXPos[node].xend, -block.ystart]);
          blockDataList.unshift(points);
          blockNode.unshift(node);
          //blockColors.unshift(refNodes.includes(node) ? refNodeColors[(idx - altNodeNum) % refNodeColors.length] : altNodePalette[(idx - refNodeNum) % altNodePalette.length]);  
          blockColors.unshift(refNodes.includes(node) ? 'rgb(' + cur_color + ',' + cur_color + ',' + cur_color + ')' : altNodePalette[(idx - refNodeNum) % altNodePalette.length]);
        });
      } else {
        nodeYRange[node].forEach(block => {
          blockDataList.unshift([
            [nodeXPos[node].xstart, -block.ystart],
            [nodeXPos[node].xstart, -block.yend],
            [nodeXPos[node].xend, -block.yend],
            [nodeXPos[node].xend, -block.ystart]
          ]);
          blockNode.unshift(node);
          //blockColors.unshift(refNodes.includes(node) ? refNodeColors[(idx - altNodeNum) % refNodeColors.length] : altNodePalette[(idx - refNodeNum) % altNodePalette.length]);
          blockColors.unshift(refNodes.includes(node) ? 'rgb(' + cur_color + ',' + cur_color + ',' + cur_color + ')' : altNodePalette[(idx - refNodeNum) % altNodePalette.length]);
        });
      }
      if (!refNodes.includes(node)) {
        altNodeNum++;
      }
    }
  });
  //console.dir(blockDataList);
  //console.dir(blockNode);
  //console.dir(blockColors);

  seriesBlockList = blockDataList.map((data, idx) => {
    return {
      type: 'custom',
      renderItem: function (params, api) {
        if (params.context.rendered) {
          return;
        }
        params.context.rendered = true;
        let points = [];
        for (let i = 0; i < data.length; i++) {

          points.push(api.coord(data[i]));

        }
        let color = blockColors[idx];
        return {
          type: 'polygon',
          transition: ['shape'],
          shape: {
            points: points
          },
          style: {
            fill: color,
            stroke: echarts.color.lift(color, 0.1)
          }
        };
      },
      xAxisIndex: 1,
      yAxisIndex: 1,
      encode: {
        x: 1,
        y: 1
      },
      clip: true,
      data: data,
      large: true,
      tooltip: {
        trigger: "item",
        formatter: function (params) {
          curVal = params.value
          return 'Node' + blockNode[idx]; //sortedNodes[blockNode[idx]];
        }
      }
    }
  })
  return {
    seriesBlockList,
    blockNode,
    blockColors
  };

}

function getLineSeries(lineData, arrorWidth, arrorColor) {

  const lineDataList = [];
  lineData.forEach(item => {
    lineDataList.push([
      [item[0], -item[2]],
      //[item[0] + arrorWidth, -((item[3] + item[2])/2 + (item[3] - item[2])/3)],
      [item[0] + arrorWidth, -(item[3] + item[2]) / 2],
      //[item[0] + arrorWidth, -((item[3] + item[2])/2 - (item[3] - item[2])/3)],
      [item[0], -item[3]],
      [item[1], -item[3]],
      //[item[1] + arrorWidth, -((item[3] + item[2])/2 + (item[3] - item[2])/3)],
      [item[1] + arrorWidth, -(item[3] + item[2]) / 2],
      //[item[1] + arrorWidth, -((item[3] + item[2])/2 - (item[3] - item[2])/3)],
      [item[1], -item[2]]
    ]);
  })


  const seriesLineList = lineDataList.map(data => {
    return {
      type: 'custom',
      renderItem: function (params, api) {
        if (params.context.rendered) {
          return;
        }
        params.context.rendered = true;
        let points = [];
        for (let i = 0; i < data.length; i++) {
          points.push(api.coord(data[i]));
        }
        return {
          type: 'polygon',
          transition: ['shape'],
          shape: {
            points: points
          },
          style: {
            fill: arrorColor
          }
        };
      },
      xAxisIndex: 1,
      yAxisIndex: 1,
      encode: {
        x: 1,
        y: 1
      },
      clip: true,
      data: data,
      large: true,
      emphasis: {
        disabled: true
      },
      tooltip: {
        show: false
      }

    }
  });

  return (seriesLineList);

}

function renderItem(params, api) {

  var categoryIndex = api.value(0);
  var start = api.coord([api.value(1), categoryIndex]);
  var end = api.coord([api.value(2), categoryIndex]);
  if (api.value(3) == 'gene') {
    var height = api.size([0, 1])[1] * 0.2;
  } else if (api.value(3) == 'transcript') {
    var height = api.size([0, 1])[1] * 0.1;
  } else if (api.value(3) == 'exon') {
    var height = api.size([0, 1])[1] * 0.6;
  } else if (api.value(3) == 'CDS') {
    var height = api.size([0, 1])[1] * 0.6;
  } else if (api.value(3) == 'UTR3') {
    var height = api.size([0, 1])[1] * 0.6;
  } else if (api.value(3) == 'UTR5') {
    var height = api.size([0, 1])[1] * 0.6;
  } else if (api.value(3) == 'repeat') {
    var height = api.size([0, 1])[1] * 0.5;
  } else if (api.value(3) == 'domain') {
    var height = api.size([0, 1])[1] * 0.5;
  } else {
    var height = api.size([0, 1])[1] * 0.5;
  }

  var rectShape = echarts.graphic.clipRectByRect({
    x: start[0],
    y: start[1] - height / 2,
    width: end[0] - start[0],
    height: height
  }, {
    x: params.coordSys.x,
    y: params.coordSys.y,
    width: params.coordSys.width,
    height: params.coordSys.height
  });
  return (
    rectShape && {
      type: 'rect',
      transition: ['shape'],
      shape: rectShape,
      style: api.style()
    }
  );
}

function convertRangesToMarkedAreas(ranges) {
  return ranges.map(item => [{
      xAxis: item[0]
    },
    {
      xAxis: item[1]
    }
  ]);
}

function getStrucSeries(strucSplitedData, refAreaColor, refMarkedArea) {
  return {
    type: 'custom',
    renderItem: renderItem,
    itemStyle: {
      opacity: 1
    },
    large: true,
    xAxisIndex: 2,
    yAxisIndex: 2,
    encode: {
      x: 4,
      y: 4
    },
    data: strucSplitedData,
    markArea: {
      itemStyle: {
        color: refAreaColor
      },
      data: refMarkedArea,
      emphasis: {
        disabled: true
      }
    },
    tooltip: {
      trigger: 'item',
      formatter: function (params) {
        curVal = params.value
        //console.dir(curVal);
        return '<h6><b>' + curVal[3] + '</b></h6><b>Chr:</b> ' + curVal[6] + '<br/><b>Start:</b> ' + curVal[7] + '<br/><b>End:</b> ' + curVal[8]

      }
    }
  };
}

function getChartOption(axisPointerColor, xMin, xMax, newXLabel, sample_n, strucYtext, seriesBlockList, seriesGraphNodeList, seriesGraphEdgeList, seriesLineList, seriesGeneStruc) {
  const option = {
    grid: [{
      left: '15%',
      top: '10%',
      height: '10%',
      width: '80%'
    }, {
      left: '15%',
      top: '20%',
      height: '37%',
      width: '80%'
    }, {
      left: '15%',
      top: '60%',
      height: '30%',
      width: '80%'
    }],
    tooltip: {
      trigger: 'axis',
      axisPointer: {
        axis: "x",
        type: "line",
        lineStyle: {
          color: "red"
        }
      }
    },
    axisPointer: {
      link: {
        xAxisIndex: [0, 1, 2]
      },
      label: {
        show: true,
        backgroundColor: axisPointerColor,
        formatter: function (value) {
          return newXLabel[Math.round(value.value) - 1];
        }
      }
    },
    xAxis: [{
      gridIndex: 0,
      type: 'value',
      scale: true,
      position: 'top',
      min: xMin,
      max: xMax,
      minInterval: 1,
      show: false,
      splitLine: {
        show: false
      }

    }, {
      gridIndex: 1,
      scale: true,
      position: 'top',
      type: "value",
      min: xMin,
      max: xMax,
      minInterval: 1,
      splitLine: {
        show: false
      },
      axisPointer: {
        label: {
          show: true
        }
      },
      axisTick: {
        show: true,
        //alignWithLabel: true
      },
      axisLabel: {
        show: true,
        fontWeight: 'bold',
        color: 'black',
        fontSize: 10,
        formatter: function (value) {
          return newXLabel[value - 1];
        }
      },
    }, {
      gridIndex: 2,
      scale: true,
      min: xMin,
      max: xMax,
      minInterval: 1,
      show: false,
      splitLine: {
        show: false
      }
    }],
    yAxis: [{
        gridIndex: 0,
        type: 'value',
        min: -3,
        max: 3,
        show: false,
        splitLine: {
          show: false
        }
      }, {
        gridIndex: 1,
        name: 'Sample Number',
        nameLocation: 'middle',
        nameGap: 130,
        min: -sample_n,
        max: 0,
        //show: false,
        splitLine: {
          show: false
        },
        nameTextStyle: {
          fontWeight: 'bold',
          color: 'black'
        },
        axisLabel: {
          show: true,
          fontWeight: 'bold',
          color: 'black',
          fontSize: 10,
          formatter: function (value) {
            return value * (-1);
          }
        }
      },
      {
        gridIndex: 2,
        data: strucYtext,
        inverse: true,
        type: 'category',
        name: "Gene",
        nameTextStyle: {
          fontWeight: 'bold',
          color: 'black'
        },
        nameLocation: 'middle',
        nameGap: 130,
        splitLine: {
          show: false
        },
        axisTick: {
          alignWithLabel: true,
          interval: 0
        },
        axisLabel: {
          show: true,
          fontWeight: 'bold',
          color: 'black',
          fontSize: 10
        }
      }

    ],
    dataZoom: [{
        type: 'slider',
        xAxisIndex: [0, 1, 2, 3, 4],
        top: 5
      },
      {
        type: 'inside',
        xAxisIndex: [0, 1, 2, 3, 4]
      },
      {
        type: 'slider',
        yAxisIndex: [2],
        //zoomLock: true,
        width: 20,
        start: 0,
        end: 100,
        handleSize: '80%',
        handleIcon: 'path://M30.9,53.2C16.8,53.2,5.3,41.7,5.3,27.6S16.8,2,30.9,2C45,2,56.4,13.5,56.4,27.6S45,53.2,30.9,53.2z M30.9,3.5C17.6,3.5,6.8,14.4,6.8,27.6c0,13.3,10.8,24.1,24.101,24.1C44.2,51.7,55,40.9,55,27.6C54.9,14.4,44.1,3.5,30.9,3.5z M36.9,35.8c0,0.601-0.4,1-0.9,1h-1.3c-0.5,0-0.9-0.399-0.9-1V19.5c0-0.6,0.4-1,0.9-1H36c0.5,0,0.9,0.4,0.9,1V35.8z M27.8,35.8 c0,0.601-0.4,1-0.9,1h-1.3c-0.5,0-0.9-0.399-0.9-1V19.5c0-0.6,0.4-1,0.9-1H27c0.5,0,0.9,0.4,0.9,1L27.8,35.8L27.8,35.8z',
        showDetail: false
      },
      {
        type: 'slider',
        yAxisIndex: [4],
        width: 20,
        start: 0,
        end: 100,
        handleSize: '80%',
        handleIcon: 'path://M30.9,53.2C16.8,53.2,5.3,41.7,5.3,27.6S16.8,2,30.9,2C45,2,56.4,13.5,56.4,27.6S45,53.2,30.9,53.2z M30.9,3.5C17.6,3.5,6.8,14.4,6.8,27.6c0,13.3,10.8,24.1,24.101,24.1C44.2,51.7,55,40.9,55,27.6C54.9,14.4,44.1,3.5,30.9,3.5z M36.9,35.8c0,0.601-0.4,1-0.9,1h-1.3c-0.5,0-0.9-0.399-0.9-1V19.5c0-0.6,0.4-1,0.9-1H36c0.5,0,0.9,0.4,0.9,1V35.8z M27.8,35.8 c0,0.601-0.4,1-0.9,1h-1.3c-0.5,0-0.9-0.399-0.9-1V19.5c0-0.6,0.4-1,0.9-1H27c0.5,0,0.9,0.4,0.9,1L27.8,35.8L27.8,35.8z',
        showDetail: false
      }
    ],
    series: [
      ...seriesBlockList,
      ...seriesGraphNodeList,
      ...seriesGraphEdgeList,
      ...seriesLineList,
      seriesGeneStruc
    ]
  };

  return (option);


}
