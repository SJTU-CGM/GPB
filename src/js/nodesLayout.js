// JavaScript Document
// 计算节点的深度
function calculateNodeDepth(nodes, edges) {
  const inDegree = {};
  const graph = {};
  nodes.forEach(node => {
    inDegree[node] = 0;
    graph[node] = [];
  });
  edges.forEach(([source, target]) => {
    graph[source].push(target);
    inDegree[target]++;
  });

  const queue = [];
  const depth = {};
  for (const node in inDegree) {
    if (inDegree[node] === 0) {
      queue.push(node);
      depth[node] = 0;
    }
  }

  while (queue.length > 0) {
    const current = queue.shift();
    const currentDepth = depth[current];
    for (const neighbor of graph[current]) {
      inDegree[neighbor]--;
      if (inDegree[neighbor] === 0) {
        queue.push(neighbor);
        depth[neighbor] = currentDepth + 1;
      }
    }
  }
  return depth;
}


// 重力法排序节点
function sortNodeInColumn(columns, edges, depth, refNodes) {
  const graph = {};
  edges.forEach(([source, target]) => {
    if (!graph[target]) graph[target] = [];
    graph[target].push(source);
  });

  for (const col in columns) {
    const nodes = columns[col];
    const weights = {};
    nodes.forEach(node => {
      if (!graph[node]) {
        weights[node] = 0;
      } else {
        const sources = graph[node];
        const totalWeight = sources.reduce((sum, source) => {
          const sourceCol = columns[depth[source]];
          return sum + sourceCol.indexOf(source) + 1;
        }, 0);
        weights[node] = totalWeight / sources.length;
      }
    });

    // 排序：优先考虑权重，权重相同则特殊节点优先
    columns[col] = nodes.sort((a, b) => {
      if (weights[a] === weights[b]) {
        return refNodes.includes(a) ? -1 : 1;
      }
      return weights[a] - weights[b];
    });
  }
}


function sortNodes(allNodes, allEdges, refNodes) {
  // 计算节点深度
  const nodeDepth = calculateNodeDepth([...allNodes], allEdges);

  // 按深度分配节点到列
  const nodeColumns = {};
  for (const node in nodeDepth) {
    const d = nodeDepth[node];
    if (!nodeColumns[d]) nodeColumns[d] = [];
    nodeColumns[d].push(node);
  }
  //console.dir(nodeColumns);

  sortNodeInColumn(nodeColumns, allEdges, nodeDepth, refNodes);
  //console.dir(nodeColumns);

  const sortedNodes = Object.values(nodeColumns).reduce((acc, val) => acc.concat(val), []);
  return (sortedNodes);
}


function getNodeXPos(graphData, sortedNodes) {
  const nodeSeqLen = graphData.node.reduce((acc, [id, sequence]) => {
    acc[id.toString()] = sequence.length;
    return acc;
  }, {});
  //console.dir(nodeSeqLen);

  const nodeXPos = {};
  //let currentX = graphData.ref.start;
  let currentX = 0.5;
  sortedNodes.forEach(node => {
    const width = nodeSeqLen[node];
    nodeXPos[node] = {
      xstart: currentX,
      xend: currentX + width
    };
    currentX += width;
  });
  return (nodeXPos);
}


function mergeRanges(ranges) {
  // 按起始坐标排序
  ranges.sort((a, b) => a[0] - b[0]);

  // 初始化结果数组
  const merged = [];

  // 遍历排序后的数组
  for (let i = 0; i < ranges.length; i++) {
    let currentRange = ranges[i];

    // 如果结果数组不为空且当前范围与最后一个合并范围连续
    if (merged.length > 0 && currentRange[0] <= merged[merged.length - 1][1]) {
      // 合并当前范围与最后一个合并范围
      merged[merged.length - 1][1] = Math.max(merged[merged.length - 1][1], currentRange[1]);
    } else {
      // 否则，将当前范围加入结果数组
      merged.push(currentRange);
    }
  }

  return merged;
}


function getRefRange(nodeXPos, refNodes) {
  const refRange = [];
  refNodes.forEach(node => {
    refRange.push([nodeXPos[node].xstart, nodeXPos[node].xend]);
  });
  //console.dir(refRange);

  const refMergedRange = mergeRanges(refRange);
  return (refMergedRange);

}


function getGroupedEdge(graphData, sortedNodes) {
  // 创建一个映射，用于快速查找每个字母的排序索引
  const sortedNodesMap = {};
  sortedNodes.forEach((letter, index) => {
    sortedNodesMap[letter] = index;
  });

  // 初始化一个空字典来存储分组后的数据
  const groupedEdge = {};

  // 按第一个字母分组
  graphData.edge.forEach(item => {
    const key = item[0];
    if (!groupedEdge[key]) {
      groupedEdge[key] = [];
    }
    groupedEdge[key].push(item);
  });
  //console.dir(groupedEdge);

  sortedNodes.forEach(item => {
    if (groupedEdge[item]) {
      groupedEdge[item].sort((a, b) => {
        // 获取每个子数组第二个字母的排序索引
        const indexA = sortedNodesMap[a[1]];
        const indexB = sortedNodesMap[b[1]];
        // 按照索引进行比较排序
        return indexA - indexB;
      });
    }
  })
  return (groupedEdge);
}


function addAndMergeIntervals(existingIntervals, newInterval) {
  // 将新区域添加到现有区域数组中
  const allIntervals = [...existingIntervals, newInterval];

  // 按 start 值排序
  allIntervals.sort((a, b) => a.ystart - b.ystart);

  // 合并重叠的区域
  const mergedIntervals = [];
  for (const interval of allIntervals) {
    if (mergedIntervals.length === 0) {
      // 如果结果数组为空，直接添加当前区域
      mergedIntervals.push(interval);
    } else {
      const lastInterval = mergedIntervals[mergedIntervals.length - 1];
      if (interval.ystart <= lastInterval.yend) {
        // 如果当前区域与最后一个区域重叠，合并它们
        lastInterval.yend = Math.max(lastInterval.yend, interval.yend);
      } else {
        // 否则，直接添加当前区域
        mergedIntervals.push(interval);
      }
    }
  }

  return mergedIntervals;
}


function removeLenFromIntervals(ranges, lengthToRemove) {
  // 初始化结果数组
  const deletedRanges = [];
  const remainingRanges = [];
  let flagI = 0;

  // 遍历已知范围
  for (let i = 0; i < ranges.length; i++) {
    let [start, end] = ranges[i];
    let remainingLength = end - start;

    // 如果当前区间的长度大于或等于需要删除的长度
    if (remainingLength >= lengthToRemove) {
      // 删除指定长度
      const deletedEnd = start + lengthToRemove;
      deletedRanges.push([start, deletedEnd]);

      // 如果删除后还有剩余部分，将剩余部分加入剩余区间范围
      if (deletedEnd < end) {
        remainingRanges.push([deletedEnd, end]);
      }
      flagI = i;

      // 退出循环，因为已经删除了足够的长度
      break;
    } else {
      // 如果当前区间的长度小于需要删除的长度
      deletedRanges.push([start, end]);
      lengthToRemove -= remainingLength; // 更新需要删除的长度
      flagI = i;
    }
  }
  // 如果还有剩余的区间，将它们加入剩余区间范围
  if (flagI + 1 < ranges.length) {
    for (let i = flagI + 1; i < ranges.length; i++) {
      remainingRanges.push(ranges[i]);
    }
  }

  return {
    deletedRanges,
    remainingRanges
  };
}


function layoutAll(sortedNodes, groupedEdge, nodeXPos, init_yend) {
  // 初始化一个对象来存储每个节点的范围
  //const nodeYRange = {
  //  1: [{ ystart: 0, yend: 185 }] // 初始范围
  //};
  const nodeYRange = {};
  nodeYRange[sortedNodes[0]] = [{
    ystart: 0,
    yend: init_yend,
    arror: [init_yend / 2]
  }] // 初始范围
  const lineData = [];
  const blockArror = {};

  // 遍历 sortedData		
  for (const curFrom of sortedNodes) {
    if (groupedEdge[curFrom]) {
      let curRangeArrs = nodeYRange[curFrom].map(range => [range.ystart, range.yend]);
      const blockStream = groupedEdge[curFrom];
      blockStream.forEach(curStream => {
        let curTo = curStream[1];
        let curLen = curStream[2];
        if (curRangeArrs) {
          const {
            deletedRanges,
            remainingRanges
          } = removeLenFromIntervals(curRangeArrs, curLen);
          deletedRanges.forEach(item => {
            const curStart = item[0];
            const curEnd = item[1];
            if (nodeYRange[curTo]) {
              nodeYRange[curTo] = addAndMergeIntervals(nodeYRange[curTo], {
                ystart: curStart,
                yend: curEnd
              });
            } else {
              nodeYRange[curTo] = [{
                ystart: curStart,
                yend: curEnd
              }];
            }
            if (sortedNodes.indexOf(String(curTo)) > sortedNodes.indexOf(String(curFrom)) + 1) {
              lineData.push([nodeXPos[curFrom].xend, nodeXPos[curTo].xstart,
                curStart + (curEnd - curStart) / 4, curStart + (curEnd - curStart) * 3 / 4
              ]);
            }
            if (blockArror[curFrom]) {
              blockArror[curFrom].push([curStart + (curEnd - curStart) / 4, curStart + (curEnd - curStart) * 3 / 4]);
            } else {
              blockArror[curFrom] = [
                [curStart + (curEnd - curStart) / 4, curStart + (curEnd - curStart) * 3 / 4]
              ];
            }
          });
          if (remainingRanges.length > 0) {
            curRangeArrs = remainingRanges;
          }
        }
      });
    }
  }
  return {
    nodeYRange,
    blockArror,
    lineData

  }
}
