

function getNodeData(nodes, sampleList) {
  nodes.forEach(node => {
    node[1] = decompressDna(node[1]);
    node[2] = restoreSampleList(node[2], sampleList);
  });

  return nodes;

}


function getNodeSeq(nodes) {
  const nodeSeq = new Map(nodes);
  for (const [k] of nodeSeq) {
    if (!k.endsWith('-')) continue;
    const fwdKey = k.slice(0, -1) + '+';
    if (!nodeSeq.has(fwdKey)) continue;
    const fwdSeq = nodeSeq.get(fwdKey);
    const revC = [...fwdSeq]
      .reverse()
      .map(b => ({
        A: 'T',
        T: 'A',
        C: 'G',
        G: 'C'
      } [b]))
      .join('');
    nodeSeq.set(k, revC);
  }
  return nodeSeq;
}


const binToDna = {
  '000': 'A',
  '001': 'T',
  '010': 'C',
  '011': 'G',
  '100': 'N'
};


function decompressDna(encodedStr) {
  if (!encodedStr || encodedStr === '') return '';

  const binaryStr = atob(encodedStr);
  const bytes = new Uint8Array(binaryStr.length);
  for (let i = 0; i < binaryStr.length; i++) {
    bytes[i] = binaryStr.charCodeAt(i);
  }

  const flag = bytes[0];
  if (flag === 0) {
    return binaryStr.slice(1);
  }

  const padding = bytes[1];
  const dataBytes = bytes.slice(2);

  let binarySeq = '';
  for (const byte of dataBytes) {
    binarySeq += byte.toString(2).padStart(8, '0');
  }

  if (padding > 0) {
    binarySeq = binarySeq.slice(0, -padding);
  }

  let dnaSeq = '';
  for (let i = 0; i < binarySeq.length; i += 3) {
    const bin = binarySeq.slice(i, i + 3);
    if (binToDna[bin]) {
      dnaSeq += binToDna[bin];
    } else {
      dnaSeq += 'N';
    }
  }

  return dnaSeq;
}


function restoreSampleList(sampleStr, sampleListStr) {
  if (sampleStr === 'ALL') return sampleListStr.slice();

  const sampleList = sampleListStr.split(',');

  const freq = sampleStr.split(',').map(s => s === '' ? 0 : Number(s));
  const out = [];
  freq.forEach((n, u) => {
    for (let i = 0; i < n; i++) out.push(sampleList[u]);
  });
  return out.join(',');
}



