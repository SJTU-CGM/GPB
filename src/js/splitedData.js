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


function splitXAxis(refMergedRange, start) {
  const newXSta = [];
  for (let i = 0; i < refMergedRange.length; i++) {
    newXSta.push(refMergedRange[i][1] - refMergedRange[i][0]);
    if (i + 1 < refMergedRange.length) {
      newXSta.push(refMergedRange[i + 1][0] - refMergedRange[i][1]);
    }
  }
  const newXLabel = [];
  let tmpX = 1;
  newXSta.forEach((item, idx) => {
    if (idx % 2 == 0) {
      const zArr = generateSequence(tmpX, tmpX + item - 1);
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
  let newXLabel2 = newXLabel.map(item => {
    if (typeof item === 'number') {
      item += Number(start - 1);
      return item.toLocaleString('en-US');
    }
    return item;
  });
  return newXLabel2;
}


function getStrucData(geneData, strucColors) {
  const strucData = [];
  let maxLineIndex = 0;
  let anchorLine = 0;
  let anchorPos = 0;

  geneData.forEach(function (gene, index) {
    const geneStart = Number(gene.start);
    const geneEnd = Number(gene.end);
    let geneLineIndex;
    if (geneStart > anchorPos) {
      geneLineIndex = 0;
      anchorLine = 0;
    } else {
      geneLineIndex = anchorLine + 1;
    }
    anchorPos = Math.max(anchorPos, geneEnd);
    strucData.push({
      name: gene.gene_id,
      value: [geneLineIndex, geneStart, geneEnd, "gene", gene.gene_id, gene.gene_id, gene.chr, gene.strand],
      itemStyle: {
        color: strucColors.gene
      }
    });
    const exonMap = {};
    (gene.ele || []).forEach(function (item) {
      if (item[0] === 'exon') {
        exonMap[item[4]] = [item[4], Number(item[1]), Number(item[2])];
      }
    });
    (gene.ele || []).forEach(function (item, idx) {
      const itemType = item[0];
      const baseValue = [Number(item[3]) + geneLineIndex, Number(item[1]), Number(item[2]), item[0], item[4], gene.gene_id, gene.chr, gene.strand];
      const extra = (itemType === 'CDS' || itemType === 'UTR5' || itemType === 'UTR3') && item[5]
        ? (exonMap[item[5]] || [null, null, null])
        : [];
      strucData.push({
        name: item[4],
        value: baseValue.concat(extra),
        itemStyle: {
          color: strucColors[item[0]]
        }
      });
      anchorLine = Math.max(anchorLine, Number(item[3]) + geneLineIndex);
      maxLineIndex = Math.max(maxLineIndex, anchorLine);
    })
  });
  const strucYtext = Array(maxLineIndex + 1).fill('');;

  return {
    strucData,
    strucYtext
  };

}


function splitStruc(strucData, refMergedRange, start) {
  const strucSplitedData = [];
  strucData.forEach(item => {
    const oldRangeStart = item.value[1] - (start - 1) - 0.5 - 0.5;
    const oldRangeEnd = item.value[2] - (start - 1) + 0.5 - 0.5;
    const upSplit = removeLenFromIntervals(refMergedRange, oldRangeStart);
    const {
      deletedRanges,
      remainingRanges
    } = removeLenFromIntervals(upSplit.remainingRanges, oldRangeEnd - oldRangeStart);
    const itemType = item.value[3];
    const isCdsOrUtr = itemType === 'CDS' || itemType === 'UTR5' || itemType === 'UTR3';
    const extra = isCdsOrUtr && item.value.length > 8
      ? [item.value[8] + ' (' + item.value[9] + '-' + item.value[10] + ')']
      : [];
    deletedRanges.forEach(range => {
      strucSplitedData.push({
        name: item.name,
        // liney, panx, pany, type, anno, start, end, geneid, chr, strand, exon_info
        value: [item.value[0], range[0], range[1], item.value[3], item.value[4], item.value[1], item.value[2], item.value[5], item.value[6], item.value[7]].concat(extra),
        itemStyle: item.itemStyle
      });
    })
  });
  return strucSplitedData;
}


function splitBed(bedData, start, refMergedRange, bedColor) {
  const bedSplitedData = [];
  if (bedData !== '') {
    const trackEnds = [];

    bedData.forEach(item => {
      const oldRangeStart = item[0] - start;
      const oldRangeEnd = item[1] - start;
      let curBedY = 0;
      while (curBedY < trackEnds.length && oldRangeStart < trackEnds[curBedY]) {
        curBedY++;
      }
      if (curBedY === trackEnds.length) {
        trackEnds.push(oldRangeEnd);
      } else {
        trackEnds[curBedY] = oldRangeEnd;
      }
      const upSplit = removeLenFromIntervals(refMergedRange, oldRangeStart);
      const {
        deletedRanges,
        remainingRanges
      } = removeLenFromIntervals(upSplit.remainingRanges, oldRangeEnd - oldRangeStart);
      deletedRanges.forEach(range => {
        bedSplitedData.push({
          name: curBedY,
          value: [curBedY, range[0], range[1], "bed", item[2], item[0], item[1], "", item[2], ""],
          itemStyle: {
            color: bedColor
          }
        });
      });
    });
  }
  const bedYtext = Array(Math.max(...bedSplitedData.map(v => v.value[0]), -1) + 1).fill('');

  return {
    bedSplitedData,
    bedYtext
  };

}
