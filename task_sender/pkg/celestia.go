package pkg

import (
	"context"
	"github.com/celestiaorg/celestia-node/blob"
	"github.com/yetanotherco/aligned_layer/common"
	serviceManager "github.com/yetanotherco/aligned_layer/contracts/bindings/AlignedLayerServiceManager"
	"log"
)

func (ts *TaskSender) PostProofOnCelestia(proof []byte) (*serviceManager.AlignedLayerServiceManagerDAPayload, error) {
	size, err := ts.celestiaConfig.Client.DA.MaxBlobSize(context.Background())
	if err != nil {
		return nil, err
	}

	proofChunks := SplitIntoChunks(proof, size)

	blobs := make([]*blob.Blob, len(proofChunks))

	log.Println("Posting proof on Celestia...")
	for idx, proofChunk := range proofChunks {
		b, err := blob.NewBlobV0(ts.celestiaConfig.Namespace, proofChunk)
		if err != nil {
			return nil, err
		}

		blobs[idx] = b
	}

	height, err := ts.celestiaConfig.Client.Blob.Submit(context.Background(), blobs, blob.DefaultGasPrice())
	if err != nil {
		return nil, err
	}

	daChunks := make([]serviceManager.AlignedLayerServiceManagerDAPayloadChunk, len(proofChunks))
	for idx, b := range blobs {
		daChunks[idx] = serviceManager.AlignedLayerServiceManagerDAPayloadChunk{
			ProofAssociatedData: b.Commitment,
			Index:               height,
		}
	}

	DAPayload := &serviceManager.AlignedLayerServiceManagerDAPayload{
		Solution: common.Celestia,
		Chunks:   daChunks,
	}

	return DAPayload, nil
}
