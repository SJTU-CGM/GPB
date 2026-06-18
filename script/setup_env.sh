#!/bin/bash
set -e

FGPB_ROOT="$(pwd)"
ENV_PATH="$HOME/.conda/envs/fGPB"

if [ ! -d "$ENV_PATH" ]; then
    ENV_PATH=$(conda info --base)/envs/fGPB
fi

mkdir -p "$ENV_PATH/etc/conda/activate.d"
mkdir -p "$ENV_PATH/etc/conda/deactivate.d"

cat > "$ENV_PATH/etc/conda/activate.d/fGPB.sh" << EOF
#!/bin/bash
export _FGPB_OLD_PATH="\$PATH"
export _FGPB_OLD_PERL5LIB="\$PERL5LIB"
export PATH="$FGPB_ROOT:\$PATH"
export PERL5LIB="$FGPB_ROOT/lib\${PERL5LIB:+:\$PERL5LIB}"
EOF

cat > "$ENV_PATH/etc/conda/deactivate.d/fGPB.sh" << 'EOF'
#!/bin/bash
export PATH="$_FGPB_OLD_PATH"
export PERL5LIB="$_FGPB_OLD_PERL5LIB"
unset _FGPB_OLD_PATH _FGPB_OLD_PERL5LIB
EOF

chmod +x "$ENV_PATH"/etc/conda/activate.d/fGPB.sh
chmod +x "$ENV_PATH"/etc/conda/deactivate.d/fGPB.sh
