import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
import joblib
import boto3
from datetime import datetime

def generate_training_data():
    """Generate synthetic house price data"""
    np.random.seed(42)
    n_samples = 1000
    
    data = {
        'bedrooms': np.random.randint(1, 6, n_samples),
        'bathrooms': np.random.randint(1, 4, n_samples),
        'sqft': np.random.normal(2000, 500, n_samples),
        'age': np.random.randint(0, 50, n_samples),
        'location_score': np.random.uniform(1, 10, n_samples)
    }
    
    df = pd.DataFrame(data)
    
    # Generate realistic prices with some noise
    df['price'] = (
        df['bedrooms'] * 50000 +
        df['bathrooms'] * 30000 +
        df['sqft'] * 150 +
        (50 - df['age']) * 1000 +
        df['location_score'] * 20000 +
        np.random.normal(0, 20000, n_samples)
    )
    
    return df

def train_model():
    """Train and save the model"""
    df = generate_training_data()
    
    features = ['bedrooms', 'bathrooms', 'sqft', 'age', 'location_score']
    X = df[features]
    y = df['price']
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    # Scale features
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    
    # Train model
    model = RandomForestRegressor(n_estimators=100, random_state=42)
    model.fit(X_train_scaled, y_train)
    
    # Calculate baseline metrics
    train_score = model.score(X_train_scaled, y_train)
    test_score = model.score(X_test_scaled, y_test)
    
    print(f"Train R²: {train_score:.4f}")
    print(f"Test R²: {test_score:.4f}")
    
    # Save model and scaler
    joblib.dump(model, 'model.pkl')
    joblib.dump(scaler, 'scaler.pkl')
    
    # Save training data statistics for drift detection
    training_stats = {
        'feature_means': X_train.mean().to_dict(),
        'feature_stds': X_train.std().to_dict(),
        'target_mean': y_train.mean(),
        'target_std': y_train.std(),
        'train_score': train_score,
        'test_score': test_score,
        'training_date': datetime.now().isoformat()
    }
    
    joblib.dump(training_stats, 'training_stats.pkl')
    
    return model, scaler, training_stats

if __name__ == "__main__":
    train_model()