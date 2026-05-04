
const palettes = [
    { type: 'discrete', colors: ["#DB7272", "#DAA628", "#38917E", "#A1D4A2", "#468BCA", "#7DD2F6", "#B384BA", "#F9BFCB"]},
    { type: 'discrete', colors: ["#8DD3C7", "#BEBADA", "#FB8072", "#80B1D3", "#FDB462", "#B3DE69", "#FCCDE5", "#BC80BD"]},
    { type: 'discrete', colors: ["#92A5D1", "#C5DFF4", "#AEB2D1", "#D9B9D4", "#7C9895", "#C9DCC4", "#DAA87C", "#F4EEAC"]},
    { type: 'discrete', colors: ["#3BA272", "#FAC858", "#73C0DE", "#EE6666", "#91CC75", "#5470C6", "#EA7CCC", "#FC8452"]},
    { type: 'discrete', colors: ["#A6CEE3", "#1F78B4", "#B2DF8A", "#33A02C", "#FB9A99", "#E31A1C", "#FDBF6F", "#FF7F00"]},	
    { type: 'discrete', colors: ["#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "#FF7F00", "#FFFF33", "#A65628", "#F781BF"]},
    { type: 'gradient', colors: ["#C3C3C3", "#5F5F5F"] },
    { type: 'gradient', colors: ["#CAE1FF", "#7e9bc0"] },
    { type: 'gradient', colors: ["#B4EEB4", "#76aa6a"] },
    { type: 'gradient', colors: ["#FFAEB9", "#cb7871"] },
];

let uiState = {
    ref: 6,     
    alt: 3,      
    arrow: '#bababa'
};


function makeColorBar(colors, type) {
    const bar = document.createElement('div');
    bar.style.width = '100%';
    bar.style.height = '20px';
    bar.style.display = 'flex';
    if (type === 'gradient') {
        bar.style.background = `linear-gradient(to right, ${colors[0]}, ${colors[1]})`;
    } else {
        colors.forEach(c => {
            const seg = document.createElement('div');
            seg.style.background = c;
            seg.style.flex = '1';
            seg.style.height = '100%';
            bar.appendChild(seg);
        });
    }
    return bar;
}


function buildDropdown(key) {
    const dropdown = document.getElementById(key + 'Dropdown');
    if (!dropdown) return;
    dropdown.innerHTML = '';
    palettes.forEach((p, i) => {
        const opt = document.createElement('div');
        opt.className = 'select-option';
        if (uiState[key] === i) opt.classList.add('active');

        const bar = makeColorBar(p.colors, p.type);
        bar.className = 'option-colors';
        opt.appendChild(bar);

        opt.onclick = (e) => {
            e.stopPropagation();
            uiState[key] = i;
            closeAll();
            updatePreview();
            if (window.onColorChange) window.onColorChange();
        };
        dropdown.appendChild(opt);
    });
}


function updateTrigger(key) {
    const idx = uiState[key];
    const p = palettes[idx];
    const triggerColors = document.getElementById(key + 'TriggerColors');
    if (!triggerColors) return;
    triggerColors.innerHTML = '';
    triggerColors.appendChild(makeColorBar(p.colors, p.type));
}


function toggleDropdown(key) {
    const wrapper = document.getElementById(key + 'Wrapper');
    if (!wrapper) return;
    const isOpen = wrapper.classList.contains('open');
    closeAll();
    if (!isOpen) wrapper.classList.add('open');
}


function closeAll() {
    document.querySelectorAll('.custom-select').forEach(el => el.classList.remove('open'));
}


function updatePreview() {
    updateTrigger('ref');
    updateTrigger('alt');
    buildDropdown('ref');
    buildDropdown('alt');

    const arrowInput = document.getElementById('arrowInput');
    if (arrowInput) {
        uiState.arrow = arrowInput.value;
		uiState.refArea = refAreaInput.value;
    }
}


function getColorConfig() {
    const refPalette = palettes[uiState.ref];
    const altPalette = palettes[uiState.alt];
    return {
        refNodeColors: refPalette.colors,
        altNodePalette: altPalette.colors,
        arrowColor: uiState.arrow,
		refAreaColor: uiState.refArea
    };
}

document.addEventListener('click', (e) => {
    if (!e.target.closest('.custom-select')) closeAll();
});

window.initColorPicker = function() {
    updatePreview();
};

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initColorPicker);
} else {
    initColorPicker();
}
