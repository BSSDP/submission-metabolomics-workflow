#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import platform
import re
import sys
import time
from pathlib import Path

import joblib
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap
import numpy as np
import pandas as pd
import scipy
import sklearn
import yaml
from scipy.special import expit
from sklearn.base import BaseEstimator, ClassifierMixin, clone
from sklearn.cross_decomposition import PLSRegression
from sklearn.discriminant_analysis import LinearDiscriminantAnalysis
from sklearn.ensemble import (
    ExtraTreesClassifier,
    GradientBoostingClassifier,
    HistGradientBoostingClassifier,
    RandomForestClassifier,
)
from sklearn.inspection import permutation_importance
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    average_precision_score,
    confusion_matrix,
    f1_score,
    roc_auc_score,
    roc_curve,
)
from sklearn.model_selection import (
    GridSearchCV,
    RepeatedStratifiedKFold,
    StratifiedKFold,
    train_test_split,
)
from sklearn.naive_bayes import GaussianNB
from sklearn.neighbors import KNeighborsClassifier
from sklearn.neural_network import MLPClassifier
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.svm import SVC


ROOT = Path(__file__).resolve().parents[2]
PALETTE = yaml.safe_load(
    (ROOT / "08_code/configs/color_palette.yml").read_text(encoding="utf-8")
)


class PLSDAClassifier(ClassifierMixin, BaseEstimator):
    def __init__(self, n_components: int = 2):
        self.n_components = n_components

    def fit(self, X, y):
        self.classes_ = np.array([0, 1])
        self.model_ = PLSRegression(n_components=self.n_components, scale=False)
        self.model_.fit(X, np.asarray(y, dtype=float))
        return self

    def decision_function(self, X):
        return np.asarray(self.model_.predict(X)).ravel()

    def predict_proba(self, X):
        probability = expit(self.decision_function(X))
        return np.column_stack([1 - probability, probability])

    def predict(self, X):
        return (self.predict_proba(X)[:, 1] >= 0.5).astype(int)

    @property
    def coef_(self):
        return np.asarray(self.model_.coef_).reshape(1, -1)


def scaled(model):
    return Pipeline([("scale", StandardScaler()), ("model", model)])


def score_vector(model, X):
    if hasattr(model, "predict_proba"):
        value = np.asarray(model.predict_proba(X))
        return value[:, 1] if value.ndim == 2 else value.ravel()
    return expit(np.asarray(model.decision_function(X)).ravel())


def model_library(seed):
    models = {
        "Logistic_L2": (
            scaled(LogisticRegression(max_iter=5000, random_state=seed)),
            {"model__C": [0.1, 1.0, 10.0]},
        ),
        "Logistic_L1": (
            scaled(
                LogisticRegression(
                    penalty="l1", solver="liblinear", max_iter=5000,
                    random_state=seed
                )
            ),
            {"model__C": [0.05, 0.2, 1.0]},
        ),
        "Linear_SVM": (
            scaled(SVC(kernel="linear", probability=True, random_state=seed)),
            {"model__C": [0.1, 1.0, 10.0]},
        ),
        "RBF_SVM": (
            scaled(SVC(kernel="rbf", probability=True, random_state=seed)),
            {"model__C": [0.5, 2.0], "model__gamma": ["scale", 0.01]},
        ),
        "PLS_DA": (
            scaled(PLSDAClassifier()),
            {"model__n_components": [1, 2, 3]},
        ),
        "LDA": (scaled(LinearDiscriminantAnalysis()), {}),
        "KNN": (scaled(KNeighborsClassifier()), {"model__n_neighbors": [3, 5, 9]}),
        "Gaussian_NB": (GaussianNB(), {"var_smoothing": [1e-11, 1e-9, 1e-7]}),
        "Random_Forest": (
            RandomForestClassifier(
                n_estimators=500, class_weight="balanced",
                random_state=seed, n_jobs=1
            ),
            {"max_features": ["sqrt", 0.3], "min_samples_leaf": [1, 3]},
        ),
        "Extra_Trees": (
            ExtraTreesClassifier(
                n_estimators=500, class_weight="balanced",
                random_state=seed, n_jobs=1
            ),
            {"max_features": ["sqrt", 0.3], "min_samples_leaf": [1, 3]},
        ),
        "Gradient_Boosting": (
            GradientBoostingClassifier(random_state=seed),
            {"n_estimators": [100, 300], "learning_rate": [0.03, 0.1]},
        ),
        "Hist_Gradient_Boosting": (
            HistGradientBoostingClassifier(random_state=seed),
            {"learning_rate": [0.03, 0.1], "max_leaf_nodes": [15, 31]},
        ),
        "MLP": (
            scaled(
                MLPClassifier(
                    max_iter=1500, early_stopping=True, random_state=seed
                )
            ),
            {"model__hidden_layer_sizes": [(32,), (64, 16)], "model__alpha": [0.001, 0.01]},
        ),
    }
    try:
        from xgboost import XGBClassifier

        models["XGBoost"] = (
            XGBClassifier(
                n_estimators=400, eval_metric="logloss", random_state=seed,
                n_jobs=1
            ),
            {"max_depth": [2, 4], "learning_rate": [0.03, 0.1]},
        )
    except ImportError:
        pass
    try:
        from lightgbm import LGBMClassifier

        models["LightGBM"] = (
            LGBMClassifier(
                n_estimators=400, random_state=seed, n_jobs=1, verbose=-1
            ),
            {"num_leaves": [7, 15], "learning_rate": [0.03, 0.1]},
        )
    except ImportError:
        pass
    try:
        from catboost import CatBoostClassifier

        models["CatBoost"] = (
            CatBoostClassifier(
                iterations=400, random_seed=seed, verbose=False,
                thread_count=1
            ),
            {"depth": [3, 5], "learning_rate": [0.03, 0.1]},
        )
    except ImportError:
        pass
    return models


def unwrap(estimator):
    return estimator.named_steps["model"] if isinstance(estimator, Pipeline) else estimator


def normalized_importance(estimator, X, y, seed):
    model = unwrap(estimator)
    if hasattr(model, "coef_"):
        importance = np.abs(np.asarray(model.coef_)).reshape(-1)
    elif hasattr(model, "feature_importances_"):
        importance = np.maximum(np.asarray(model.feature_importances_), 0)
    else:
        importance = np.maximum(
            permutation_importance(
                estimator, X, y, scoring="roc_auc", n_repeats=3,
                random_state=seed, n_jobs=1
            ).importances_mean,
            0,
        )
    if importance.size != X.shape[1] or not np.isfinite(importance).all():
        raise ValueError("Invalid feature-importance vector")
    total = importance.sum()
    return importance / total if total > 0 else np.repeat(1 / importance.size, importance.size)


def bootstrap_auc(y, score, iterations, seed):
    rng = np.random.default_rng(seed)
    values = []
    y = np.asarray(y)
    score = np.asarray(score)
    for _ in range(iterations):
        index = rng.integers(0, len(y), len(y))
        if np.unique(y[index]).size == 2:
            values.append(roc_auc_score(y[index], score[index]))
    return np.quantile(values, [0.025, 0.975]) if values else (np.nan, np.nan)


def metrics(y, score, threshold=0.5):
    predicted = (score >= threshold).astype(int)
    tn, fp, fn, tp = confusion_matrix(y, predicted, labels=[0, 1]).ravel()
    safe = lambda numerator, denominator: numerator / denominator if denominator else np.nan
    return {
        "roc_auc": roc_auc_score(y, score),
        "pr_auc": average_precision_score(y, score),
        "accuracy": accuracy_score(y, predicted),
        "sensitivity": safe(tp, tp + fn),
        "specificity": safe(tn, tn + fp),
        "ppv": safe(tp, tp + fp),
        "npv": safe(tn, tn + fn),
        "f1": f1_score(y, predicted, zero_division=0),
        "threshold": threshold,
    }


def read_inputs(config):
    model_cfg = config["modeling"]
    matrix = pd.read_csv(ROOT / model_cfg["curated_matrix"], sep="\t")
    annotation = [
        "metabolite_id", "common_name", "display_name", "mode", "source_feature_id"
    ]
    missing = [column for column in annotation if column not in matrix.columns]
    if missing:
        raise ValueError(f"Curated matrix lacks columns: {missing}")
    metadata = pd.read_csv(ROOT / model_cfg["metadata"], sep="\t")
    sample_column = model_cfg["matrix_sample_id_column"]
    group_column = model_cfg["group_column"]
    sample_ids = metadata[sample_column].astype(str)
    matrix_samples = [column for column in matrix.columns if column not in annotation]
    if set(sample_ids) != set(matrix_samples):
        raise ValueError("Model matrix and metadata sample IDs do not match")
    X = matrix.set_index("metabolite_id")[sample_ids].T
    y = (
        metadata.set_index(sample_column).loc[sample_ids, group_column]
        == model_cfg["positive_class"]
    ).astype(int)
    display_by_id = matrix.set_index("metabolite_id")["display_name"].to_dict()
    original_columns = list(X.columns)
    safe_columns = [f"F{index:06d}" for index in range(1, len(original_columns) + 1)]
    original_ids = dict(zip(safe_columns, original_columns))
    labels = {
        safe: display_by_id.get(original, original)
        for safe, original in original_ids.items()
    }
    X.columns = safe_columns
    return X, y, metadata, labels, original_ids


def reserve_figure(slug, module):
    slug = re.sub(r"[^A-Za-z0-9]+", "_", slug).strip("_")
    figure_root = ROOT / "05_figures"
    existing = list(figure_root.rglob(f"[0-9]*_{slug}.pdf"))
    if existing:
        prefix = existing[0].name.split("_", 1)[0]
    else:
        numbers = []
        for path in figure_root.rglob("*"):
            match = re.match(r"^(\d+)_", path.name)
            if path.is_file() and match:
                numbers.append(int(match.group(1)))
        prefix = f"{max(numbers, default=0) + 1:02d}"
    directory = figure_root / "unassigned" / module
    directory.mkdir(parents=True, exist_ok=True)
    return prefix, slug, directory / f"{prefix}_{slug}"


def save_figure(fig, stem, dpi=600):
    for extension in ["pdf", "svg", "png", "tiff"]:
        fig.savefig(
            stem.with_suffix(f".{extension}"), dpi=dpi,
            bbox_inches="tight", facecolor="white"
        )
    plt.close(fig)


def plot_style():
    plt.rcParams.update(
        {
            "font.family": "Arial",
            "font.size": 8,
            "axes.spines.top": False,
            "axes.spines.right": False,
            "axes.linewidth": 0.5,
            "figure.facecolor": "white",
            "axes.facecolor": "white",
        }
    )


def register_figure(
    prefix, slug, stem, source_path, message, plot_type,
    width_mm, height_mm
):
    map_path = ROOT / "00_project_management/FIGURE_MAP.tsv"
    rows = pd.read_csv(map_path, sep="\t")
    figure_id = f"{prefix}_{slug.upper()}"
    if not rows.empty and figure_id in set(rows["figure_id"].astype(str)):
        return
    row = {
        "figure_id": figure_id,
        "panel_id": np.nan,
        "status": "done",
        "result_section": "unassigned",
        "message": message,
        "plot_type": plot_type,
        "analysis_id": "M08_modeling",
        "source_data_file": source_path.relative_to(ROOT).as_posix(),
        "script_file": "08_code/python/modeling.py",
        "output_pdf": stem.with_suffix(".pdf").relative_to(ROOT).as_posix(),
        "output_svg": stem.with_suffix(".svg").relative_to(ROOT).as_posix(),
        "output_png": stem.with_suffix(".png").relative_to(ROOT).as_posix(),
        "output_tiff": stem.with_suffix(".tiff").relative_to(ROOT).as_posix(),
        "width_mm": width_mm,
        "height_mm": height_mm,
        "journal_role": "unassigned",
        "legend_status": "pending",
        "decision": "pending",
    }
    pd.concat([rows, pd.DataFrame([row])], ignore_index=True).to_csv(
        map_path, sep="\t", index=False
    )


def single_feature_roc(
    X, y, feature_keys, source_dir, seed, folds, repeats,
    labels, original_ids, bootstrap_iterations
):
    splitter = RepeatedStratifiedKFold(
        n_splits=folds, n_repeats=repeats, random_state=seed
    )
    rows = []
    for feature_key in feature_keys:
        values = X[[feature_key]].to_numpy().reshape(-1, 1)
        feature_id = original_ids[feature_key]
        display_name = labels[feature_key]
        probability_sum = np.zeros(len(y), dtype=float)
        probability_count = np.zeros(len(y), dtype=int)
        fold_rows = []
        for fold_id, (train_index, validation_index) in enumerate(
            splitter.split(values, y), start=1
        ):
            estimator = scaled(
                LogisticRegression(max_iter=3000, random_state=seed)
            )
            estimator.fit(values[train_index], y.iloc[train_index])
            fold_probability = estimator.predict_proba(
                values[validation_index]
            )[:, 1]
            probability_sum[validation_index] += fold_probability
            probability_count[validation_index] += 1
            fold_rows.extend(
                {
                    "sample_id": X.index[index],
                    "fold_id": fold_id,
                    "true_label": int(y.iloc[index]),
                    "predicted_probability": float(probability),
                    "feature_id": feature_id,
                    "display_name": display_name,
                }
                for index, probability in zip(validation_index, fold_probability)
            )
        probabilities = probability_sum / probability_count
        auc = roc_auc_score(y, probabilities)
        lower, upper = bootstrap_auc(
            y, probabilities, bootstrap_iterations, seed
        )
        fpr, tpr, thresholds = roc_curve(y, probabilities)
        prefix, slug, stem = reserve_figure(
            f"single_feature_ROC_{display_name}", "metabolomics_single_feature_roc"
        )
        source = pd.DataFrame(
            {
                "sample_id": X.index,
                "true_label": y.to_numpy(),
                "predicted_probability": probabilities,
                "feature_id": feature_id,
                "display_name": display_name,
            }
        )
        source_path = source_dir / f"{prefix}_{slug}_source.tsv"
        source.to_csv(source_path, sep="\t", index=False)
        pd.DataFrame(fold_rows).to_csv(
            source_dir / f"{prefix}_{slug}_fold_predictions.tsv",
            sep="\t", index=False
        )
        fig, ax = plt.subplots(figsize=(3.6, 3.3))
        ax.plot(fpr, tpr, color=PALETTE["heatmap"]["low"], lw=1.2)
        ax.plot(
            [0, 1], [0, 1], color=PALETTE["directions"]["background"],
            ls="--", lw=0.7
        )
        ax.set(xlabel="False positive rate", ylabel="True positive rate")
        ax.set_title(
            f"{display_name}\nAUC = {auc:.3f} ({lower:.3f}-{upper:.3f})",
            loc="left", fontweight="bold"
        )
        save_figure(fig, stem)
        register_figure(
            prefix, slug, stem, source_path,
            f"Single-feature ROC: {display_name}", "ROC", 91, 84
        )
        rows.append(
            {
                "feature_key": feature_key,
                "feature_id": feature_id,
                "display_name": display_name,
                "oof_auc": auc,
                "auc_ci_lower": lower,
                "auc_ci_upper": upper,
            }
        )
    return pd.DataFrame(rows)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default="08_code/configs/project.yml")
    args = parser.parse_args()
    config = yaml.safe_load((ROOT / args.config).read_text(encoding="utf-8"))
    model_cfg = config["modeling"]
    if not model_cfg.get("enabled", False):
        print("Modeling is disabled in project.yml; nothing to run.")
        return 0

    seed = int(config["project"]["seed"])
    np.random.seed(seed)
    plot_style()
    X, y, metadata, labels, original_ids = read_inputs(config)
    train_ids, test_ids = train_test_split(
        np.arange(len(y)),
        test_size=float(model_cfg["test_fraction"]),
        stratify=y,
        random_state=seed,
    )
    X_train, X_test = X.iloc[train_ids], X.iloc[test_ids]
    y_train, y_test = y.iloc[train_ids], y.iloc[test_ids]
    cv = RepeatedStratifiedKFold(
        n_splits=int(model_cfg["cv_folds"]),
        n_repeats=int(model_cfg["cv_repeats"]),
        random_state=seed,
    )

    output_dir = ROOT / "04_analysis/R07_modeling_or_clinical_extension/M08_modeling/outputs"
    model_dir = output_dir / "models"
    source_dir = ROOT / "05_figures/figure_source_data"
    for directory in [output_dir, model_dir, source_dir]:
        directory.mkdir(parents=True, exist_ok=True)

    split_table = metadata.copy()
    split_table["model_split"] = "unused"
    split_table.loc[train_ids, "model_split"] = "train"
    split_table.loc[test_ids, "model_split"] = "test"
    split_table.to_csv(output_dir / "sample_split.tsv", sep="\t", index=False)

    resampling_rows = []
    for split_id, (fold_train, fold_validation) in enumerate(
        cv.split(X_train, y_train), start=1
    ):
        resampling_rows.extend(
            {
                "split_id": split_id,
                "sample_id": X_train.index[index],
                "role": "train",
                "true_label": int(y_train.iloc[index]),
            }
            for index in fold_train
        )
        resampling_rows.extend(
            {
                "split_id": split_id,
                "sample_id": X_train.index[index],
                "role": "validation",
                "true_label": int(y_train.iloc[index]),
            }
            for index in fold_validation
        )
    pd.DataFrame(resampling_rows).to_csv(
        output_dir / "resampling_assignments.tsv", sep="\t", index=False
    )

    performance = []
    importance_rows = []
    prediction_rows = []
    skipped_models = []
    started = time.time()
    for model_name, (estimator, grid) in model_library(seed).items():
        print(f"Training {model_name}")
        try:
            search = GridSearchCV(
                estimator, grid or [{}], scoring="roc_auc", cv=cv,
                n_jobs=int(model_cfg["n_jobs"]), refit=True,
            )
            with joblib.parallel_backend("threading"):
                search.fit(X_train, y_train)
            best = search.best_estimator_
            pd.DataFrame(search.cv_results_).to_csv(
                output_dir / f"{model_name}_cv_results.tsv",
                sep="\t", index=False
            )
            test_score = score_vector(best, X_test)
            row = metrics(y_test, test_score)
            lower, upper = bootstrap_auc(
                y_test, test_score, int(model_cfg["bootstrap_iterations"]), seed
            )
            row.update(
                {
                    "model": model_name,
                    "cv_auc": search.best_score_,
                    "test_auc_ci_lower": lower,
                    "test_auc_ci_upper": upper,
                    "best_params": json.dumps(search.best_params_, sort_keys=True),
                }
            )
            performance.append(row)
            importance = normalized_importance(best, X_train, y_train, seed)
            ranks = scipy.stats.rankdata(-importance, method="average")
            importance_rows.extend(
                {
                    "model": model_name,
                    "feature_key": feature,
                    "feature_id": original_ids[feature],
                    "display_name": labels[feature],
                    "importance": value,
                    "rank": rank,
                    "cv_auc_weight": search.best_score_,
                }
                for feature, value, rank in zip(X.columns, importance, ranks)
            )
            prediction_rows.extend(
                {
                    "model": model_name,
                    "sample_id": X_test.index[i],
                    "true_label": int(y_test.iloc[i]),
                    "predicted_probability": float(test_score[i]),
                    "predicted_label": int(test_score[i] >= 0.5),
                    "threshold": 0.5,
                    "split": "test",
                }
                for i in range(len(y_test))
            )
            joblib.dump(best, model_dir / f"{model_name}.joblib")
        except Exception as exc:
            skipped_models.append(
                {"model": model_name, "error": f"{type(exc).__name__}: {exc}"}
            )
            print(f"Skipping {model_name}: {exc}", file=sys.stderr)

    performance = pd.DataFrame(performance).sort_values("cv_auc", ascending=False)
    importance = pd.DataFrame(importance_rows)
    predictions = pd.DataFrame(prediction_rows)
    if performance.empty:
        raise RuntimeError("Every configured model failed.")
    performance.to_csv(output_dir / "model_performance.tsv", sep="\t", index=False)
    importance.to_csv(output_dir / "model_specific_importance.tsv", sep="\t", index=False)
    predictions.to_csv(output_dir / "test_predictions.tsv", sep="\t", index=False)
    pd.DataFrame(skipped_models, columns=["model", "error"]).to_csv(
        output_dir / "skipped_models.tsv", sep="\t", index=False
    )

    importance["weighted_rank"] = importance["rank"] * importance["cv_auc_weight"]
    consensus = (
        importance.groupby(
            ["feature_key", "feature_id", "display_name"], as_index=False
        )
        .agg(
            weighted_rank_sum=("weighted_rank", "sum"),
            weight_sum=("cv_auc_weight", "sum"),
            mean_importance=("importance", "mean"),
        )
    )
    consensus["weighted_mean_rank"] = (
        consensus["weighted_rank_sum"] / consensus["weight_sum"]
    )
    consensus = consensus.sort_values(
        ["weighted_mean_rank", "feature_id"]
    ).reset_index(drop=True)
    consensus["consensus_rank"] = np.arange(1, len(consensus) + 1)
    consensus.to_csv(output_dir / "consensus_importance.tsv", sep="\t", index=False)

    prefix, slug, stem = reserve_figure(
        "model_crossvalidated_and_test_AUC", "metabolomics_modeling"
    )
    performance_source = source_dir / f"{prefix}_{slug}_source.tsv"
    performance.to_csv(performance_source, sep="\t", index=False)
    view = performance.sort_values("cv_auc")
    fig, ax = plt.subplots(figsize=(5.0, max(3.4, 0.25 * len(view))))
    y_position = np.arange(len(view))
    ax.scatter(
        view["cv_auc"], y_position,
        color=PALETTE["ion_modes"]["negative"], label="CV AUC"
    )
    ax.scatter(
        view["roc_auc"], y_position,
        color=PALETTE["ion_modes"]["positive"], label="Test AUC"
    )
    ax.set_yticks(y_position, view["model"])
    ax.set(xlabel="ROC AUC", xlim=(0, 1.02))
    ax.set_title("Classifier performance", loc="left", fontweight="bold")
    ax.legend(frameon=False)
    save_figure(fig, stem)
    register_figure(
        prefix, slug, stem, performance_source,
        "Cross-validated and held-out classifier performance",
        "model_performance_dotplot", 127, max(86, 6.35 * len(view))
    )

    top_n = int(model_cfg["consensus_top_n"])
    top = consensus.head(top_n).sort_values("weighted_mean_rank", ascending=False)
    prefix, slug, stem = reserve_figure(
        "consensus_feature_importance", "metabolomics_modeling"
    )
    importance_source = source_dir / f"{prefix}_{slug}_source.tsv"
    top.to_csv(importance_source, sep="\t", index=False)
    fig, ax = plt.subplots(figsize=(5.0, max(3.5, 0.22 * len(top))))
    ax.barh(
        top["display_name"], 1 / top["weighted_mean_rank"],
        color=PALETTE["heatmap"]["low"]
    )
    ax.set_xlabel("Inverse weighted mean rank")
    ax.set_title("Consensus metabolite importance", loc="left", fontweight="bold")
    save_figure(fig, stem)
    register_figure(
        prefix, slug, stem, importance_source,
        "Consensus metabolite importance across classifiers",
        "horizontal_bar", 127, max(89, 5.59 * len(top))
    )

    volcano_path = ROOT / model_cfg.get("integrated_volcano_result", "")
    if volcano_path.is_file():
        volcano = pd.read_csv(volcano_path, sep="\t")
        merged = volcano.merge(
            consensus[["feature_id", "consensus_rank"]],
            on="feature_id", how="left"
        )
        merged["importance_color"] = 1 / merged["consensus_rank"]
        prefix, slug, stem = reserve_figure(
            "differential_metabolites_colored_by_model_rank",
            "metabolomics_modeling"
        )
        integrated_source = source_dir / f"{prefix}_{slug}_source.tsv"
        merged.to_csv(integrated_source, sep="\t", index=False)
        fig, ax = plt.subplots(figsize=(4.2, 3.4))
        importance_cmap = LinearSegmentedColormap.from_list(
            "importance",
            [PALETTE["heatmap"]["mid"], PALETTE["heatmap"]["low"]]
        )
        points = ax.scatter(
            merged["log2FC"], merged["neg_log10_FDR"],
            c=merged["importance_color"], cmap=importance_cmap,
            s=10, alpha=0.75, edgecolors="none"
        )
        ax.set(xlabel="log2 fold change", ylabel=r"$-\log_{10}$(FDR)")
        ax.set_title(
            "Differential change and model importance",
            loc="left", fontweight="bold"
        )
        fig.colorbar(points, ax=ax, label="Inverse consensus rank")
        save_figure(fig, stem)
        register_figure(
            prefix, slug, stem, integrated_source,
            "Differential metabolites colored by consensus model rank",
            "integrated_volcano", 107, 86
        )

    selected = consensus.head(int(model_cfg["single_feature_roc_top_n"]))[
        "feature_key"
    ].tolist()
    pattern = model_cfg.get("single_feature_include_regex", "")
    if pattern:
        selected.extend(
            feature for feature in X.columns
            if re.search(pattern, labels[feature], flags=re.I)
        )
    selected = list(dict.fromkeys(selected))
    single_summary = single_feature_roc(
        X, y, selected, source_dir, seed,
        int(model_cfg["cv_folds"]), int(model_cfg["cv_repeats"]),
        labels, original_ids, int(model_cfg["bootstrap_iterations"])
    )
    single_summary.to_csv(
        output_dir / "single_feature_roc_summary.tsv", sep="\t", index=False
    )

    environment = {
        "python": sys.version,
        "platform": platform.platform(),
        "numpy": np.__version__,
        "pandas": pd.__version__,
        "scipy": scipy.__version__,
        "scikit_learn": sklearn.__version__,
        "elapsed_seconds": time.time() - started,
        "seed": seed,
    }
    (output_dir / "python_environment.json").write_text(
        json.dumps(environment, indent=2), encoding="utf-8"
    )
    print("Modeling complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
