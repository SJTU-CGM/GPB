// JavaScript Document

function statNodeSampleN(edges) {
  const nodeSampleN1 = new Map();
  const nodeSampleN2 = new Map();

  edges.forEach(subArray => {
    const [node1, node2, number] = subArray;
    if (nodeSampleN1.has(node1)) {
      nodeSampleN1.set(node1, nodeSampleN1.get(node1) + number);
    } else {
      nodeSampleN1.set(node1, number);
    }
    if (nodeSampleN2.has(node2)) {
      nodeSampleN2.set(node2, nodeSampleN2.get(node2) + number);
    } else {
      nodeSampleN2.set(node2, number);
    }
  });
  return (new Map([...nodeSampleN1, ...nodeSampleN2]));
}


function generateSequence(start, end) {
  return Array.from({
    length: end - start + 1
  }, (_, index) => start + index);
}


function splitXAixs(refMergedRange, start) {
  const newXSta = [];
  for (let i = 0; i < refMergedRange.length; i++) {
    newXSta.push(refMergedRange[i][1] - refMergedRange[i][0]);
    if (i + 1 < refMergedRange.length) {
      newXSta.push(refMergedRange[i + 1][0] - refMergedRange[i][1]);
    }
  }
  //console.dir(newXSta);		

  const newXLabel = [];
  let tmpX = 1;
  newXSta.forEach((item, idx) => {
    if (idx % 2 == 0) {
      const zArr = generateSequence(tmpX, tmpX + item - 1);
      //newXLabel.push(...generateSequence(tmpX, tmpX + item));
      for (let i = 0; i < zArr.length; i++) {
        newXLabel.push(zArr[i]);
      }
      tmpX += item;
    } else {
      if (item > 0) {
        newXLabel.push(...new Array(item).fill(''));
      }
    }
  });
  //console.dir(newXLabel);
  //console.dir(start);
  let newXLabel2 = newXLabel.map(item => {
    if (typeof item === 'number') {
      item += Number(start - 1);
      return item.toLocaleString('en-US'); // 格式化数字
    }
    return item; // 保留字符不变
  });

  return (newXLabel2);
}

function getStrucData(geneData, transData, elementData, strucColors) {
  const strucData = [];
  const strucYtext = [];

  strucData.push({
    name: 0,
    value: [geneData.idx, geneData.start, geneData.end, geneData.group, geneData.gene_id, geneData.chr],
    itemStyle: {
      color: strucColors.gene
    }
  });
  strucYtext.push(geneData.gene_id);

  transData.forEach(function (item, index) {
    strucData.push({
      name: index + 1,
      //value:[item.idx, item.start, item.end, item.group, item.ID, item.chr],
      value: [Number(item[2]), Number(item[0]), Number(item[1]), "transcript", item[3], geneData.chr],
      itemStyle: {
        color: strucColors.transcript
      }
    })
    strucYtext.push(item[3]);
  });

  elementData.forEach(function (item, index) {
    //console.dir(item);
    strucData.push({
      name: index + 1,
      //value:[item.idx, item.start, item.end, item.group, item.ID, item.chr, 
      value: [Number(item[2]), Number(item[0]), Number(item[1]), item[3], "", geneData.chr],
      itemStyle: {
        color: strucColors[item[3]]
      }
    });
  });

  return {
    strucData,
    strucYtext
  }
}


function splitStuc(strucData, refMergedRange, start) {
  const strucSplitedData = [];
  strucData.forEach(item => {
    //console.dir(item.value);
    const oldRangeStart = item.value[1] - (start - 1) - 0.5 - 0.5;
    const oldRangeEnd = item.value[2] - (start - 1) + 0.5 - 0.5;
    const upSplit = removeLenFromIntervals(refMergedRange, oldRangeStart);
    const {
      deletedRanges,
      remainingRanges
    } = removeLenFromIntervals(upSplit.remainingRanges, oldRangeEnd - oldRangeStart);
    //console.dir(deletedRanges);
    deletedRanges.forEach(range => {
      strucSplitedData.push({
        name: item.name,
        value: [item.value[0], range[0], range[1], ...item.value.slice(3, item.value.length), ...item.value.slice(1, 3)],
        itemStyle: item.itemStyle
      });
    })
  });
  return (strucSplitedData);
}

