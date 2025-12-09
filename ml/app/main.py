from fastapi import FastAPI
from typing import List, Optional
import pandas as pd
import os

app = FastAPI()

# Simple in-memory mock for now, or load from CSV if available
DATA_PATH = os.getenv("DATA_PATH", "/app/data")

@app.get("/")
def read_root():
    return {"service": "RiceAgent ML"}

@app.get("/recommend")
def recommend(customerId: str):
    # In a real scenario, we'd load the trained model and predict
    # For this scaffold, we return dummy product IDs
    return {
        "recommendations": [
            {"productId": "prod-1", "score": 0.95},
            {"productId": "prod-2", "score": 0.88}
        ]
    }

@app.get("/anomaly")
def anomaly(productId: str, price: float):
    # Simple Z-score check stub
    return {
        "is_anomaly": False,
        "z_score": 0.5,
        "historical_mean": 45.0,
        "historical_std": 2.0
    }

@app.post("/train")
def train():
    # Trigger training logic
    return {"status": "Training started"}
