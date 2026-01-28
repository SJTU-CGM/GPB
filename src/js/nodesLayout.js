

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
    columns[col] = nodes.sort((a, b) => {
      if (weights[a] === weights[b]) {
        return refNodes.includes(a) ? -1 : 1;
      }
      return weights[a] - weights[b];
    });
  }
}


function sortNodes(allNodes, allEdges, refNodes) {
  const nodeDepth = calculateNodeDepth([...allNodes], allEdges);
  const nodeColumns = {};
  for (const node in nodeDepth) {
    const d = nodeDepth[node];
    if (!nodeColumns[d]) nodeColumns[d] = [];
    nodeColumns[d].push(node);
  }
  sortNodeInColumn(nodeColumns, allEdges, nodeDepth, refNodes);
  const sortedNodes = Object.values(nodeColumns).reduce((acc, val) => acc.concat(val), []);
  return sortedNodes;
}


function getNodeXPos(nodeSeq, sortedNodes) {
  const nodeXPos = {};
  let currentX = 0.5;
  sortedNodes.forEach(segment => {
    const width = nodeSeq.get(segment).replace(/,/g, '').length;
    nodeXPos[segment] = {
      xstart: currentX,
      xend: currentX + width
    };
    currentX += width;
  });
  return nodeXPos;
}


function mergeRanges(ranges) {
  ranges.sort((a, b) => a[0] - b[0]);
  const merged = [];
  for (let i = 0; i < ranges.length; i++) {
    let currentRange = ranges[i];
    if (merged.length > 0 && currentRange[0] <= merged[merged.length - 1][1]) {
      merged[merged.length - 1][1] = Math.max(merged[merged.length - 1][1], currentRange[1]);
    } else {
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
  const refMergedRange = mergeRanges(refRange);
  return refMergedRange;
}


function getGroupedEdge(graphData, sortedNodes) {
  const sortedNodesMap = {};
  sortedNodes.forEach((letter, index) => {
    sortedNodesMap[letter] = index;
  });
  const groupedEdge = {};
  graphData.edge.forEach(item => {
    const key = item[0];
    if (!groupedEdge[key]) {
      groupedEdge[key] = [];
    }
    groupedEdge[key].push(item);
  });
  sortedNodes.forEach(item => {
    if (groupedEdge[item]) {
      groupedEdge[item].sort((a, b) => {
        const indexA = sortedNodesMap[a[1]];
        const indexB = sortedNodesMap[b[1]];
        return indexA - indexB;
      });
    }
  })
  return groupedEdge;
}


function mergeReverse(sortedNodes, groupedEdge, nodeSeq, nodeSample, nodeData) {
  const toReplace = [];
  const toRemove = new Set();
  const phenoFlag = nodeData.every(a => a[3] !== undefined);

  for (let i = 0; i < sortedNodes.length; i++) {
    const u = sortedNodes[i];
    if (!u.endsWith('-')) continue;
    const outs = groupedEdge[Object.keys(groupedEdge).find(k => k === u || k.endsWith(',' + u))];
    if (!outs || outs.length !== 1) continue;
    const [from1, to1, n1] = outs[0];
    if (!to1.endsWith('-')) continue;
    if (!groupedEdge[to1]) continue;
    const cnt = Object.keys(groupedEdge).filter(k => groupedEdge[k].some(e => e[1] === to1)).length;
    if (cnt > 1) continue;
    const newName = `${from1},${to1}`;
    groupedEdge[to1].forEach((val, idx) => {
      const [from2, to2, n2] = val;
      if (!groupedEdge[newName]) groupedEdge[newName] = [];
      groupedEdge[newName].push([newName, to2, n2]);
    })
    delete groupedEdge[from1];
    delete groupedEdge[to1];

    const seq1 = nodeSeq.get(from1) || '';
    const seq2 = nodeSeq.get(to1) || '';
    const newSeq = [seq1, seq2].filter(Boolean).join(',');
    nodeSeq.delete(from1);
    nodeSeq.delete(to1);
    nodeSeq.set(newName, newSeq);

    const smp1 = nodeSample.get(from1) || '';
    const smp2 = nodeSample.get(to1) || '';
    const set = new Set([
      ...smp1.split(',').filter(Boolean),
      ...smp2.split(',').filter(Boolean)
    ]);
    const newSmp = Array.from(set).sort().join(',');
    nodeSample.delete(from1);
    nodeSample.delete(to1);
    nodeSample.set(newName, newSmp);

    Object.values(groupedEdge).forEach(arr => arr.forEach(r => {
      if (r[1] === from1) r[1] = newName;
    }));

    if (phenoFlag) {
      nodeData.forEach(row => {
        if (row[0] === from1) row[0] = newName;
      });
      nodeData = nodeData.filter(row => row[0] !== to1);
    }

    toReplace.push({
      idx: sortedNodes.indexOf(from1.split(',')[0]),
      newName
    });
    toRemove.add(to1);
  }

  toReplace.forEach(({
    idx,
    newName
  }) => {
    if (idx === -1) return;

    const oldVal = sortedNodes[idx];
    sortedNodes[idx] = newName;

    const zeroPlus = groupedEdge['0+'];
    if (Array.isArray(zeroPlus)) {
      zeroPlus.forEach(triple => {
        if (triple[1] === oldVal) triple[1] = newName;
      });
    }
  });

  const rmIdx = [];
  sortedNodes.forEach((v, i) => {
    if (toRemove.has(v)) rmIdx.push(i);
  });
  rmIdx.reverse().forEach(i => sortedNodes.splice(i, 1));
	
}


function addAndMergeIntervals(existingIntervals, newInterval) {
  const allIntervals = [...existingIntervals, newInterval];
  allIntervals.sort((a, b) => a.ystart - b.ystart);
  const mergedIntervals = [];
	
  for (const interval of allIntervals) {
    if (mergedIntervals.length === 0) {
      mergedIntervals.push(interval);
    } else {
      const lastInterval = mergedIntervals[mergedIntervals.length - 1];
      if (interval.ystart <= lastInterval.yend) {
        lastInterval.yend = Math.max(lastInterval.yend, interval.yend);
      } else {
        mergedIntervals.push(interval);
      }
    }
  }
	
  return mergedIntervals;
}


function removeLenFromIntervals(ranges, lengthToRemove) {
  const deletedRanges = [];
  const remainingRanges = [];
  let flagI = 0;
	
  for (let i = 0; i < ranges.length; i++) {
    let [start, end] = ranges[i];
    let remainingLength = end - start;
    if (remainingLength >= lengthToRemove) {
      const deletedEnd = start + lengthToRemove;
      deletedRanges.push([start, deletedEnd]);
      if (deletedEnd < end) {
        remainingRanges.push([deletedEnd, end]);
      }
      flagI = i;
      break;
    } else {
      deletedRanges.push([start, end]);
      lengthToRemove -= remainingLength;
      flagI = i;
    }
  }
	
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
  const nodeYRange = {};
  nodeYRange[sortedNodes[0]] = [{
    ystart: 0,
    yend: init_yend,
    arror: [init_yend / 2]
  }]
  const lineData = [];
  const blockArror = {};

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
  };
}
